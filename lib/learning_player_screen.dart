import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class LearningPlayerScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  LearningPlayerScreen({required this.courseId, required this.courseTitle});

  @override
  _LearningPlayerScreenState createState() => _LearningPlayerScreenState();
}

class _LearningPlayerScreenState extends State<LearningPlayerScreen> with WidgetsBindingObserver {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(protocolWhitelist: ['http', 'https', 'tcp', 'tls']),
  );
  late final VideoController _videoController = VideoController(
    _player,
    configuration: const VideoControllerConfiguration(
      hwdec: 'mediacodec', 
      enableHardwareAcceleration: true,
    ),
  );

  String? currentVideoUrl;
  String? currentLessonId;
  String? currentDescription;
  List<DocumentSnapshot> lessons = [];
  List<dynamic> completedLessonIds = [];
  Map<String, dynamic> resumePoints = {}; 
  String? _lastWatchedLessonId; 
  
  bool _userDataLoaded = false; 
  bool _hasStartedInitialVideo = false; 
  bool _isDescriptionExpanded = false; 
  bool _isPlayerAlive = true; 
  bool _controlsVisible = true;
  bool _isSeeking = false; // New: Tracks background resume process

  Timer? _authPlayTimer; 
  Timer? _hideTimer;
  int _secondsRemaining = 5;
  bool _showAutoplayOverlay = false;

  StreamSubscription? _activeSeekSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLearningFlow(); 
    _startHideTimer(); 
    
    _player.stream.completed.listen((isCompleted) {
      final pos = _player.state.position.inSeconds;
      final dur = _player.state.duration.inSeconds;
      if (isCompleted && currentLessonId != null && pos >= dur - 3) {
        _toggleComplete(currentLessonId!, true);
        _startAutoplayCountdown();
      }
    });

    _player.stream.position.listen((pos) {
      if (mounted && currentLessonId != null && !_isSeeking) {
        if (pos.inSeconds != (resumePoints[currentLessonId] as num? ?? 0).toInt()) {
          setState(() {
            resumePoints[currentLessonId!] = pos.inSeconds;
          });
        }
      }
    });
  }

  // --- LOGIC UPDATED FOR RESUME POINTS ---

  Future<void> _playLesson(String url, String lessonId, String description, {bool isInitial = false}) async {
    if (url.isEmpty || (currentVideoUrl == url && !isInitial) || !_isPlayerAlive) return;
    
    if (!isInitial) _saveProgress(); 
    _cancelAutoplay();
    _activeSeekSubscription?.cancel();

    setState(() {
      currentVideoUrl = url;
      currentLessonId = lessonId;
      currentDescription = description;
      _isDescriptionExpanded = false; 
      _controlsVisible = true;
      _isSeeking = true; // Show loader while we find the resume point
    });

    // 1. Update Firestore Last Watched
    String uid = FirebaseAuth.instance.currentUser!.uid;
    FirebaseFirestore.instance.collection('users').doc(uid).update({'lastLessonWatched': lessonId});

    // 2. Open media PAUSED
    await _player.open(Media(url), play: false); 

    int savedSec = (resumePoints[lessonId] as num? ?? 0).toInt();

    if (savedSec > 3) {
      // 3. Wait for metadata to be ready
      _activeSeekSubscription = _player.stream.duration.listen((Duration duration) async {
        if (duration.inSeconds > 0) {
          _activeSeekSubscription?.cancel();
          
          // Small buffer to allow engine to stabilize
          await Future.delayed(const Duration(milliseconds: 600));
          
          // Perform the seek
          await _player.seek(Duration(seconds: savedSec));
          
          // Wait for seek to complete and buffer to catch up
          await Future.delayed(const Duration(milliseconds: 600));

          if (mounted) {
            setState(() => _isSeeking = false); // Hide loader
            _player.play();
          }
        }
      });
    } else {
      // No resume point needed
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() => _isSeeking = false);
        _player.play();
      }
    }
  }

  // --- END OF LOGIC UPDATES ---

  void _saveProgress() async {
    if (currentLessonId == null || !_isPlayerAlive || _isSeeking) return;
    String uid = FirebaseAuth.instance.currentUser!.uid;
    int position = _player.state.position.inSeconds;
    int duration = _player.state.duration.inSeconds;

    if (position > 5 && (duration == 0 || position < duration - 5)) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'resumePoints.$currentLessonId': position 
      });
    } else if (position >= duration - 5 && duration > 0) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'resumePoints.$currentLessonId': FieldValue.delete()
      });
    }
  }

  void _initLearningFlow() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    var lessonSnap = await FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .collection('lessons')
        .orderBy('order')
        .get();

    if (!mounted) return;
    lessons = lessonSnap.docs;

    FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> incoming = data['resumePoints'] ?? {};
        resumePoints = Map<String, dynamic>.from(incoming); 
        
        setState(() {
          completedLessonIds = data['completedLessons'] ?? [];
          _lastWatchedLessonId = data['lastLessonWatched'];
          _userDataLoaded = true; 
        });

        if (!_hasStartedInitialVideo && lessons.isNotEmpty) {
          _hasStartedInitialVideo = true; 
          _triggerStartupVideo();
        }
      }
    });
  }

  void _triggerStartupVideo() async {
    int startIndex = -1;
    if (_lastWatchedLessonId != null) {
      startIndex = lessons.indexWhere((doc) => doc.id == _lastWatchedLessonId);
    }
    if (startIndex == -1) {
      for (int i = 0; i < lessons.length; i++) {
        String lId = lessons[i].id;
        if (resumePoints.containsKey(lId) || !completedLessonIds.contains(lId)) {
          startIndex = i;
          break; 
        }
      }
    }
    if (startIndex == -1) startIndex = 0;
    
    _playLesson(
      lessons[startIndex]['videoUrl'], 
      lessons[startIndex].id, 
      lessons[startIndex]['description'] ?? "",
      isInitial: true,
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 
      ? "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds" 
      : "$twoDigitMinutes:$twoDigitSeconds";
  }

  double _parseDuration(String durationStr) {
    try {
      List<String> parts = durationStr.trim().split(':');
      if (parts.length == 3) return (double.parse(parts[0]) * 3600) + (double.parse(parts[1]) * 60) + double.parse(parts[2]);
      if (parts.length == 2) return (double.parse(parts[0]) * 60) + double.parse(parts[1]);
      return double.tryParse(durationStr) ?? 0.0;
    } catch (e) { return 0.0; }
  }

  void _startAutoplayCountdown() {
    int currentIndex = lessons.indexWhere((l) => l.id == currentLessonId);
    if (currentIndex != -1 && currentIndex < lessons.length - 1) {
      setState(() { _secondsRemaining = 5; _showAutoplayOverlay = true; });
      _authPlayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_secondsRemaining > 1) { _secondsRemaining--; } 
          else { _cancelAutoplay(); _playAdjacent(1); }
        });
      });
    }
  }

  void _cancelAutoplay() => setState(() { _authPlayTimer?.cancel(); _showAutoplayOverlay = false; });

  void _playAdjacent(int offset) {
    int currentIndex = lessons.indexWhere((l) => l.id == currentLessonId);
    int nextIndex = currentIndex + offset;
    if (nextIndex >= 0 && nextIndex < lessons.length) {
      var nextLesson = lessons[nextIndex];
      _playLesson(nextLesson['videoUrl'], nextLesson.id, nextLesson['description'] ?? "");
    }
  }

  void _toggleComplete(String lessonId, bool isDone) async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'completedLessons': isDone ? FieldValue.arrayUnion([lessonId]) : FieldValue.arrayRemove([lessonId])
    });
  }

  @override
  void dispose() {
    _saveProgress();
    _activeSeekSubscription?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.removeObserver(this);
    _killAudioEngine();
    super.dispose();
  }

  void _killAudioEngine() {
    if (!_isPlayerAlive) return;
    setState(() => _isPlayerAlive = false);
    _authPlayTimer?.cancel();
    _hideTimer?.cancel();
    _player.stop();
    _player.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) _startHideTimer();
    });
  }

  void _toggleRotation() {
    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    int currentIndex = lessons.indexWhere((l) => l.id == currentLessonId);
    bool hasPrevious = currentIndex > 0;
    bool hasNext = currentIndex != -1 && currentIndex < lessons.length - 1;

    Widget videoPlayer = GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          Video(controller: _videoController, controls: NoVideoControls),
          if (_controlsVisible)
            Positioned.fill(
              child: Container(
                color: const Color(0x70000000), 
                child: Stack(
                  children: [
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(icon: Icon(Icons.skip_previous, color: hasPrevious ? Colors.white : Colors.white24, size: 36), onPressed: hasPrevious ? () => _playAdjacent(-1) : null),
                          IconButton(icon: const Icon(Icons.replay_10, color: Colors.white, size: 36), onPressed: () => _player.seek(_player.state.position - const Duration(seconds: 10))),
                          StreamBuilder<bool>(
                            stream: _player.stream.playing,
                            builder: (context, snapshot) => IconButton(
                              icon: Icon(snapshot.data == true ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: isLandscape ? 80 : 60),
                              onPressed: () => _player.playOrPause(),
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.forward_10, color: Colors.white, size: 36), onPressed: () => _player.seek(_player.state.position + const Duration(seconds: 10))),
                          IconButton(icon: Icon(Icons.skip_next, color: hasNext ? Colors.white : Colors.white24, size: 36), onPressed: hasNext ? () => _playAdjacent(1) : null),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: isLandscape ? 25 : 10, left: 20, right: 20,
                      child: Row(
                        children: [
                          StreamBuilder(
                            stream: _player.stream.position,
                            builder: (context, snapshot) => Text(
                              "${_formatDuration(snapshot.data ?? Duration.zero)} / ${_formatDuration(_player.state.duration)}",
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: StreamBuilder(
                              stream: _player.stream.position,
                              builder: (context, pos) => Slider(
                                activeColor: const Color(0xFFD4A373), 
                                value: (pos.data?.inSeconds.toDouble() ?? 0).clamp(0, _player.state.duration.inSeconds.toDouble() > 0 ? _player.state.duration.inSeconds.toDouble() : 1), 
                                max: _player.state.duration.inSeconds.toDouble() > 0 ? _player.state.duration.inSeconds.toDouble() : 1, 
                                onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
                                onChangeEnd: (v) => _saveProgress(),
                              ),
                            ),
                          ),
                          IconButton(icon: Icon(isLandscape ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white), onPressed: _toggleRotation),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_showAutoplayOverlay)
            Positioned.fill(
              child: Container(
                color: const Color(0xB3000000), 
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("UP NEXT", style: TextStyle(color: Color(0xFFD4A373), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("Starting in $_secondsRemaining...", style: const TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 20),
                      SizedBox(width: 40, height: 40, child: CircularProgressIndicator(value: _secondsRemaining / 5, color: const Color(0xFFD4A373), strokeWidth: 3)),
                      const SizedBox(height: 20),
                      TextButton(onPressed: _cancelAutoplay, child: const Text("CANCEL", style: TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.underline)))
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (isLandscape) { _toggleRotation(); return; }
        _saveProgress(); _killAudioEngine(); 
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: isLandscape ? null : AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFFD4A373)), onPressed: () { _saveProgress(); _killAudioEngine(); Navigator.pop(context); }),
          title: Text(widget.courseTitle, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15)),
        ),
        body: Stack(
          children: [
            isLandscape 
              ? videoPlayer 
              : Column(
                  children: [
                    AspectRatio(aspectRatio: 16 / 9, child: videoPlayer),
                    const SizedBox(height: 8),
                    _buildDescriptionSection(),
                    Expanded(child: _buildLessonList()),
                  ],
                ),
            // Updated Loader Condition
            if (!_userDataLoaded || !_hasStartedInitialVideo || _isSeeking)
              Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 100, child: LinearProgressIndicator(color: Color(0xFFD4A373), backgroundColor: Colors.white10, minHeight: 2)),
                    const SizedBox(height: 20),
                    Text(
                      _isSeeking ? "RESUMING..." : "PREPARING YOUR LESSON...",
                      style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return GestureDetector(
      onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
      child: Container(
        width: double.infinity, 
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(color: Color(0xFF121212), border: Border(top: BorderSide(color: Colors.white10, width: 0.5), bottom: BorderSide(color: Colors.white10, width: 1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Text("LESSON DETAILS", style: GoogleFonts.poppins(color: const Color(0xFFD4A373), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)), 
                  const SizedBox(width: 8), 
                  Icon(_isDescriptionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFFD4A373), size: 16)
                ]),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0), 
                child: Text(currentDescription ?? "", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, height: 1.5))
              ),
              crossFadeState: _isDescriptionExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst, 
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildLessonList() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('courses').doc(widget.courseId).collection('lessons').orderBy('order').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || !_userDataLoaded) return const SizedBox();
      lessons = snapshot.data!.docs;

      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: lessons.length,
        itemBuilder: (context, index) {
          var lessonDoc = lessons[index];
          String thisLessonId = lessonDoc.id; 
          bool isSelected = currentLessonId == thisLessonId;
          bool isDone = completedLessonIds.contains(thisLessonId);
          
          // 1. Parse Durations
          String durStr = lessonDoc['duration']?.toString() ?? "0";
          double totalSecs = _parseDuration(durStr);
          double currentSecs = (resumePoints[thisLessonId] as num? ?? 0).toDouble();

          // 2. Calculate Progress & Percentage
          double progress = 0.0;
          int percentRemaining = 100;
          
          if (isDone) {
            progress = 1.0;
            percentRemaining = 0;
          } else if (totalSecs > 0) {
            progress = (currentSecs / totalSecs).clamp(0.0, 1.0);
            percentRemaining = 100 - (progress * 100).toInt();
          }

          // Only show progress bar if they've actually started (more than 2 seconds in)
          bool shouldShowProgress = isDone || (currentSecs > 2);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? const Color(0xFFD4A373) : Colors.white10),
            ),
            child: Column(
              children: [
                ListTile(
                  onTap: () => _playLesson(lessonDoc['videoUrl'], thisLessonId, lessonDoc['description'] ?? ""),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: isDone 
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 22) 
                    : Icon(isSelected ? Icons.play_arrow : Icons.play_arrow_outlined, 
                        color: isSelected ? const Color(0xFFD4A373) : Colors.white24),
                  title: Text(lessonDoc['title'], 
                    style: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.white60, fontSize: 14)),
                  // 3. Re-added the Percentage Text here
                  trailing: isDone 
                    ? const Text("FINISHED", style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold))
                    : (currentSecs > 5) 
                        ? Text("$percentRemaining% REMAINING", 
                            style: const TextStyle(color: Color(0xFFD4A373), fontSize: 9, fontWeight: FontWeight.bold))
                        : Text(durStr, style: const TextStyle(color: Colors.white10, fontSize: 11)),
                ),
                if (shouldShowProgress)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white10,
                        color: isDone ? Colors.green : const Color(0xFFD4A373),
                        minHeight: 2,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}
}