import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;

  const CustomVideoPlayer({
    super.key, 
    required this.videoUrl, 
    required this.title
  });

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  // Design Palette
  final Color goldAccent = const Color(0xFFD4A373);
  final Color pureBlack = const Color(0xFF000000); 
  
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    
    try {
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: goldAccent,
          handleColor: goldAccent,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
      );
    } catch (e) {
      debugPrint("Video Error: $e");
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pureBlack, // Pure black background
      appBar: AppBar(
        backgroundColor: pureBlack,
        elevation: 0,
        centerTitle: true,
        // 1. FIXED BACK ICON: Small gold iOS-style chevron
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: goldAccent, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
        // 2. FIXED COLOUR & STYLE: Branded Gold "MAKEUP" title
        title: Text(
          "MAKEUP", 
          style: GoogleFonts.montserrat(
            fontSize: 12,           
            fontWeight: FontWeight.w900, 
            color: goldAccent,
            letterSpacing: 5.0,     
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Player Section
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: _chewieController != null &&
                        _chewieController!.videoPlayerController.value.isInitialized
                    ? Chewie(controller: _chewieController!)
                    : Center(
                        child: CircularProgressIndicator(
                          color: goldAccent,
                          strokeWidth: 2,
                        ),
                      ),
              ),
            ),

            // Video Title & Details Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "MASTERCLASS SERIES",
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: goldAccent.withOpacity(0.7),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
}