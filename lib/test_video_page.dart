import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';

class VideoTestPage extends StatefulWidget {
  const VideoTestPage({super.key});
  @override
  State<VideoTestPage> createState() => _VideoTestPageState();
}

class _VideoTestPageState extends State<VideoTestPage> {
  // 1. Optimized Player for HTTP & Nothing Phone
  late final Player player = Player(
    configuration: const PlayerConfiguration(
      protocolWhitelist: ['http', 'https', 'tcp', 'tls', 'file', 'data'],
    ),
  );

  // 2. Optimized Controller for GPU Acceleration
  late final VideoController controller = VideoController(
    player,
    configuration: const VideoControllerConfiguration(
      hwdec: 'mediacodec', 
      enableHardwareAcceleration: true,
    ),
  );
  
  String statusMessage = "Initializing Video...";

  @override
  void initState() {
    super.initState();

    player.stream.error.listen((error) {
      if (mounted) setState(() => statusMessage = "Error: $error");
    });

    player.stream.buffering.listen((isBuffering) {
      if (mounted) {
        setState(() => statusMessage = isBuffering ? "Buffering..." : "Ready to Play");
      }
    });

    // 3. YOUR MAIN VIDEO LINK
    player.open(
      Media('http://samandjas.com/appassets/videos/makeup1/vidonebig.mp4'),
      play: false,
    );

    // Give the Nothing Phone OS time to prepare the GPU surface
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        player.play();
        setState(() => statusMessage = "Playback Started");
      }
    });
  }

  @override
  void dispose() {
    player.dispose(); // CRITICAL: Free up the GPU hardware for the next video
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF1), // Matching your Sam & Jas theme
      appBar: AppBar(title: const Text("Sam & Jas Video Test")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              color: Colors.black,
              child: Video(
                controller: controller,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.width * 9 / 16,
              ),
            ),
            const SizedBox(height: 20),
            Text(statusMessage, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => player.play(),
              icon: const Icon(Icons.play_arrow),
              label: const Text("FORCE PLAY"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4A373)),
            ),
          ],
        ),
      ),
    );
  }
}