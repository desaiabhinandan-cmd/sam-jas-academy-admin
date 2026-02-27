import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ZoomView extends StatefulWidget {
  final String meetingId;
  final String password;

  const ZoomView({super.key, required this.meetingId, required this.password});

  @override
  State<ZoomView> createState() => _ZoomViewState();
}

class _ZoomViewState extends State<ZoomView> {
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Start joining immediately
    _handleJoin();
  }

  Future<void> _handleJoin() async {
    setState(() => _hasError = false);

    // 1. Clean the Meeting ID (removes spaces/dashes)
    final String cleanId = widget.meetingId.replaceAll(RegExp(r'[\s\-]+'), '');
    
    // 2. Format the URL for 2026 standards
    // Using the 'j' (join) endpoint is more stable for deep-linking
    final Uri zoomUri = Uri.parse("https://zoom.us/j/$cleanId?pwd=${widget.password}");

    try {
      // 3. Attempt to launch with a timeout safety
      final bool launched = await launchUrl(
        zoomUri, 
        mode: LaunchMode.externalApplication,
      ).timeout(const Duration(seconds: 10));

      if (!launched) throw 'Launch failed';

      // 4. If successful, wait a moment then go back
      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open Zoom. Please install Zoom or use Chrome."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // High-quality dark theme
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_hasError) ...[
                const CircularProgressIndicator(color: Colors.amber, strokeWidth: 3),
                const SizedBox(height: 30),
                const Text(
                  "Connecting to Live Class...",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "We're opening Zoom for you",
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ] else ...[
                const Icon(Icons.error_outline, color: Colors.amber, size: 60),
                const SizedBox(height: 20),
                const Text(
                  "Connection Issue",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _handleJoin,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  child: const Text("Retry Joining", style: TextStyle(color: Colors.black)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Go Back", style: TextStyle(color: Colors.white70)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}