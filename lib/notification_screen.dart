import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'live_hub_screen.dart'; 

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // Dynamic icons based on the notification type
  IconData _getIcon(String? type) {
    switch (type) {
      case 'live_session':
        return Icons.videocam_outlined;
      case 'course':
        return Icons.play_circle_outline;
      case 'payment':
        return Icons.receipt_long;
      case 'announcement':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  // Clear all notifications using a WriteBatch
  Future<void> _clearAllNotifications(BuildContext context, String uid) async {
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');

    final snapshots = await collection.get();
    if (snapshots.docs.isEmpty) return;

    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("Clear All?", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Delete all notifications permanently?", style: GoogleFonts.montserrat(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("DELETE ALL", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final Color goldAccent = const Color(0xFFD4A373);
    final Color charcoalBg = const Color(0xFF121212);

    return Scaffold(
      backgroundColor: charcoalBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Announcements", 
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: goldAccent)),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
            onPressed: () => _clearAllNotifications(context, uid),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: goldAccent));
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: goldAccent.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text("No notifications yet", 
                    style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              bool isRead = data['isRead'] ?? false;
              String type = data['type'] ?? 'general';
              String title = data['title'] ?? "Notification";
              String message = data['message'] ?? data['body'] ?? "";
              
              DateTime? timeData = (data['timestamp'] as Timestamp?)?.toDate();
              String formattedTime = timeData != null 
                  ? DateFormat('hh:mm a').format(timeData) 
                  : "";

              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                ),
                onDismissed: (direction) => doc.reference.delete(),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white.withOpacity(0.05) : goldAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isRead ? Colors.white10 : goldAccent.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isRead ? Colors.white10 : goldAccent.withOpacity(0.2),
                      child: Icon(_getIcon(type), color: isRead ? Colors.white24 : goldAccent, size: 20),
                    ),
                    title: Text(
                      type == 'live_session' ? "$title ($formattedTime)" : title, 
                      style: GoogleFonts.montserrat(
                        color: isRead ? Colors.white60 : Colors.white, 
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.bold, 
                        fontSize: 14
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(message, style: GoogleFonts.montserrat(color: isRead ? Colors.white38 : Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text(
                          timeData != null ? DateFormat('dd MMM, yyyy').format(timeData) : "",
                          style: const TextStyle(color: Colors.white24, fontSize: 10),
                        ),
                      ],
                    ),
                    onTap: () async {
                      // 1. Mark as read
                      doc.reference.update({'isRead': true});

                      // 2. Handle Navigation for Live Classes
                      if (type == 'live_session') {
                        String courseId = data['courseId'] ?? "";
                        
                        // Check if session is still active
                        var liveDoc = await FirebaseFirestore.instance.collection('live_sessions').doc(courseId).get();
                        bool stillLive = liveDoc.exists && (liveDoc.data()?['isLive'] ?? false);

                        if (stillLive) {
                          if (context.mounted) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const LiveHubScreen()));
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Session has ended."), backgroundColor: Colors.orangeAccent),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}