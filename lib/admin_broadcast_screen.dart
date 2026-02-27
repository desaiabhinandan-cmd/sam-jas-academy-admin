import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final Color goldAccent = const Color(0xFFD4A373);
  bool _isSending = false;

  // Generic broadcast helper (Sends to Topic: all_students + Saves to every user's feed)
  Future<void> _sendBroadcastNotification({
    required String title, 
    required String body, 
    String? payload
  }) async {
    setState(() => _isSending = true);
    
    // 1. Send Push via FCM
    await NotificationService.sendBroadcast(
      title: title,
      body: body,
      screenPayload: payload,
    );

    // 2. Sync to Firestore so it appears in the Notification Screen
    try {
      final users = await FirebaseFirestore.instance.collection('users').get();
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in users.docs) {
        var notifRef = doc.reference.collection('notifications').doc();
        batch.set(notifRef, {
          'title': title,
          'body': body,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': payload == 'course_list' ? 'course' : 'announcement',
        });
      }
      await batch.commit();
    } catch (e) {
      print("Firestore Broadcast Sync Error: $e");
    }

    _finishSend(title);
  }

  // SMART NUDGE: Targets individual tokens + saves to their personal feed
  Future<void> _handleSmartCartNudge() async {
    setState(() => _isSending = true);
    int count = 0;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('hasActiveCart', isEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        String? token = doc.data()['fcmToken'];
        
        // Save to their Notification Screen feed
        await doc.reference.collection('notifications').add({
          'title': "Your Cart is Waiting! ✨",
          'body': "Finish your enrollment now to secure your spot.",
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'payment',
        });

        if (token != null) {
          await NotificationService.sendDirectMessage(
            token: token,
            title: "Your Cart is Waiting! ✨",
            body: "Finish your enrollment now to secure your spot.",
            payload: "cart_screen",
          );
          count++;
        }
      }
      _finishSend("Smart Nudge sent to $count users");
    } catch (e) {
      _finishSend("Error: $e");
    }
  }

  // INACTIVE USER NUDGE: Targets users based on lastActivity
  Future<void> _handleInactiveNudge() async {
    setState(() => _isSending = true);
    int count = 0;
    DateTime threshold = DateTime.now().subtract(const Duration(days: 7));

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('lastActivity', isLessThan: Timestamp.fromDate(threshold))
          .get();

      for (var doc in snapshot.docs) {
        String? token = doc.data()['fcmToken'];

        // Save to Database
        await doc.reference.collection('notifications').add({
          'title': "We Miss You! 👋",
          'body': "Come back and see what's new at Sam & Jas Academy.",
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'general',
        });

        if (token != null) {
          await NotificationService.sendDirectMessage(
            token: token,
            title: "We Miss You! 👋",
            body: "Come back and see what's new at Sam & Jas Academy.",
            payload: "home",
          );
          count++;
        }
      }
      _finishSend("Wake-up nudge sent to $count users");
    } catch (e) {
      _finishSend("Error: $e");
    }
  }

  void _finishSend(String message) {
    setState(() => _isSending = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message), 
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "BROADCAST CENTER", 
          style: GoogleFonts.montserrat(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 18)
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Smart Scenarios", 
              style: GoogleFonts.montserrat(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 16)
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                _buildScenarioCard("New Course", Icons.play_circle_fill, () {
                  _sendBroadcastNotification(
                    title: "New Course Added! 🎓",
                    body: "A fresh masterclass is waiting for you. Start learning now!",
                    payload: "course_list"
                  );
                }),
                const SizedBox(width: 12),
                _buildScenarioCard("Smart Nudge", Icons.shopping_cart, _handleSmartCartNudge),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildScenarioCard("Inactive User", Icons.wb_sunny_rounded, _handleInactiveNudge),
                const SizedBox(width: 12),
                _buildScenarioCard("Daily Tip", Icons.lightbulb, () {
                  _sendBroadcastNotification(
                    title: "Pro Tip of the Day 💡",
                    body: "Consistency is the key to mastery. Keep practicing!",
                    payload: "home"
                  );
                }),
              ],
            ),

            const SizedBox(height: 40),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24),

            Text(
              "Custom Announcement", 
              style: GoogleFonts.montserrat(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 16)
            ),
            const SizedBox(height: 24),
            _buildLabel("Notification Title"),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("e.g., Important Maintenance Update"),
            ),
            const SizedBox(height: 24),
            _buildLabel("Message Body"),
            TextField(
              controller: _messageController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Enter your custom message here..."),
            ),
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSending ? null : () {
                   if (_titleController.text.isNotEmpty && _messageController.text.isNotEmpty) {
                      _sendBroadcastNotification(
                        title: _titleController.text, 
                        body: _messageController.text
                      );
                      _titleController.clear();
                      _messageController.clear();
                   }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSending 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text(
                      "SEND CUSTOM BROADCAST", 
                      style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.bold)
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioCard(String title, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Icon(icon, color: goldAccent, size: 28),
              const SizedBox(height: 8),
              Text(title, style: GoogleFonts.montserrat(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text, 
        style: GoogleFonts.montserrat(color: goldAccent, fontWeight: FontWeight.w600, fontSize: 13)
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: goldAccent)),
    );
  }
}