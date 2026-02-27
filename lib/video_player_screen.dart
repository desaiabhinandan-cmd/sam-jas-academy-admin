import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; 

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? lessonId; 

  const VideoPlayerScreen({super.key, required this.videoUrl, required this.title, this.lessonId});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with WidgetsBindingObserver, RouteAware {
  YoutubePlayerController? _controller;
  bool _isResumed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    _controller = YoutubePlayerController(
      initialVideoId: videoId!,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
      ),
    )..addListener(_onControllerChange); 
  }

  void _onControllerChange() {
    // UPDATED: isReady isn't enough; we wait for the player to start playing
    // to ensure the seek command actually executes.
    if (_controller!.value.playerState == PlayerState.playing && !_isResumed && widget.lessonId != null) {
      _isResumed = true;
      _checkAndResume();
    }
  }

  Future<void> _checkAndResume() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        Map<String, dynamic>? resumePoints = userDoc.data()?['resumePoints'];
        if (resumePoints != null && resumePoints.containsKey(widget.lessonId)) {
          int savedSeconds = resumePoints[widget.lessonId];
          if (savedSeconds > 3) {
             // Tiny delay to let the iFrame stabilize
            await Future.delayed(const Duration(milliseconds: 500));
            _controller?.seekTo(Duration(seconds: savedSeconds));
            debugPrint("DEBUG: Jumped to $savedSeconds seconds for ${widget.lessonId}");
          }
        }
      }
    } catch (e) {
      debugPrint("DEBUG: Error fetching resume point: $e");
    }
  }

  void _saveYouTubeProgress() async {
    // If you see this in console, your navigation isn't passing the ID
    if (widget.lessonId == null || widget.lessonId!.isEmpty) {
      debugPrint("DEBUG: Progress NOT saved because lessonId is NULL or EMPTY");
      return;
    }
    
    if (_controller == null) return;
    
    String uid = FirebaseAuth.instance.currentUser!.uid;
    int currentSecond = _controller!.value.position.inSeconds;

    if (currentSecond > 3) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'resumePoints': {widget.lessonId: currentSecond}
        }, SetOptions(merge: true));
        debugPrint("DEBUG: Progress Saved: $currentSecond seconds");
      } catch (e) {
        debugPrint("DEBUG: Firestore Save Error: $e");
      }
    }
  }

  @override
  void dispose() {
    _saveYouTubeProgress(); 
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveYouTubeProgress();
      _controller?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video-${widget.videoUrl}'),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction == 0 && mounted) {
          _saveYouTubeProgress(); 
          _controller?.pause();
        }
      },
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) _saveYouTubeProgress();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFFFFDF1),
          appBar: AppBar(
            backgroundColor: const Color(0xFF4A342B),
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _saveYouTubeProgress();
                Navigator.pop(context);
              },
            ),
            title: Text(widget.title, style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white)),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                if (_controller != null)
                  YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: const Color(0xFFD4A373),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    widget.title,
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4A342B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}