import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart'; 

class AdminLiveClassScreen extends StatefulWidget {
  const AdminLiveClassScreen({super.key});

  @override
  State<AdminLiveClassScreen> createState() => _AdminLiveClassScreenState();
}

class _AdminLiveClassScreenState extends State<AdminLiveClassScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final Color goldAccent = const Color(0xFFD4A373);
  final Color charcoalBg = const Color(0xFF121212);

  final TextEditingController _meetingIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedCourseId;      
  String? _selectedCourseTitle;   

  Future<void> _loadExistingSessionData(String courseId) async {
    try {
      var doc = await _firestore.collection("live_sessions").doc(courseId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _meetingIdController.text = data['meetingId']?.toString() ?? "";
          _passwordController.text = data['password']?.toString() ?? "";
        });
      } else {
        setState(() {
          _meetingIdController.clear();
          _passwordController.clear();
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
  }

  Future<void> _notifyCourseStudents(String title) async {
    if (_selectedCourseId == null) return;
    
    try {
      // 1. Find all students enrolled in this specific course
      QuerySnapshot userSnapshot = await _firestore
          .collection('users')
          .where('enrolledCourses', arrayContains: _selectedCourseId)
          .get();

      WriteBatch batch = _firestore.batch();

      for (var userDoc in userSnapshot.docs) {
        // 2. Reference to student's personal notification sub-collection
        DocumentReference notifyRef = _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .doc();

        // 3. Set the notification data
        batch.set(notifyRef, {
          'title': '🎥 Class is LIVE!',
          'message': 'The session for $title has started. Tap to join now!',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'type': 'live_session',
          'courseId': _selectedCourseId,
        });
      }

      // 4. Commit all student notifications
      await batch.commit();

      // 5. Send the Broadcast Push Notification
      String sanitizedId = _selectedCourseId!.trim().replaceAll(' ', '_');
      String topicName = 'course_$sanitizedId';
      
      await NotificationService.sendBroadcast(
        title: "🎥 Class is LIVE!",
        body: "The session for $title has started. Join now!",
        topic: topicName, 
        screenPayload: "dashboard_screen",
      );
    } catch (e) {
      debugPrint("❌ Notification Error: $e");
    }
  }

  Future<void> _updateLiveStatus(bool isLive) async {
  if (_selectedCourseId == null) return;

  // --- NEW VALIDATION START ---
  if (isLive) {
    String mId = _meetingIdController.text.trim();
    String mPass = _passwordController.text.trim();

    if (mId.isEmpty || mPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Please enter both Meeting ID and Password to go LIVE"),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return; // Stop execution here
    }
  }
  // --- NEW VALIDATION END ---

  try {
    await _firestore.collection("live_sessions").doc(_selectedCourseId).set({
      'courseName': _selectedCourseTitle,
      'isLive': isLive,
      'meetingId': isLive ? _meetingIdController.text.trim() : "",
      'password': isLive ? _passwordController.text.trim() : "",
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (isLive) {
      await _notifyCourseStudents(_selectedCourseTitle!);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isLive ? "LIVE Started & Notified" : "Session Ended"),
          backgroundColor: isLive ? Colors.green : Colors.red,
        ),
      );
    }
  } catch (e) {
    debugPrint("❌ Update Error: $e");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: charcoalBg,
      appBar: AppBar(
        title: Text(
          "ZOOM LIVE CLASSES", 
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold, 
            fontSize: 18, 
            color: goldAccent, 
            letterSpacing: 1.1,
          ),
        ),
        backgroundColor: charcoalBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection("courses").snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: goldAccent.withOpacity(0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCourseId,
                      hint: Text("Select Course to Go Live", style: TextStyle(color: goldAccent.withOpacity(0.7))),
                      dropdownColor: charcoalBg,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: goldAccent),
                      items: snapshot.data!.docs.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(doc['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final doc = snapshot.data!.docs.firstWhere((d) => d.id == val);
                          setState(() {
                            _selectedCourseId = val;
                            _selectedCourseTitle = doc['title'];
                          });
                          _loadExistingSessionData(val);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 25),
            _buildInput(_meetingIdController, "Zoom Meeting ID", Icons.numbers),
            const SizedBox(height: 15),
            _buildInput(_passwordController, "Zoom Password", Icons.lock_outline),
            const SizedBox(height: 30),
            
            StreamBuilder<DocumentSnapshot>(
              stream: _selectedCourseId == null 
                ? null 
                : _firestore.collection("live_sessions").doc(_selectedCourseId).snapshots(),
              builder: (context, liveSnapshot) {
                bool isCurrentlyLive = false;
                if (liveSnapshot.hasData && liveSnapshot.data!.exists) {
                  isCurrentlyLive = liveSnapshot.data!['isLive'] ?? false;
                }

                return Column(
                  children: [
                    _actionButton(
                      "START SESSION & NOTIFY", 
                      Colors.green, 
                      () => _updateLiveStatus(true),
                      isEnabled: !isCurrentlyLive && _selectedCourseId != null,
                    ),
                    const SizedBox(height: 15),
                    _actionButton(
                      "END SESSION", 
                      Colors.redAccent, 
                      () => _updateLiveStatus(false), 
                      isOutlined: true,
                      isEnabled: isCurrentlyLive && _selectedCourseId != null,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap, {bool isOutlined = false, bool isEnabled = true}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: isOutlined 
        ? OutlinedButton(
            onPressed: isEnabled ? onTap : null, 
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isEnabled ? color : Colors.white10), 
              foregroundColor: color, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isEnabled ? color : Colors.white24)),
          )
        : ElevatedButton(
            onPressed: isEnabled ? onTap : null, 
            style: ElevatedButton.styleFrom(
              backgroundColor: isEnabled ? color : Colors.white.withOpacity(0.1), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: isEnabled ? 2 : 0,
            ),
            child: Text(label, style: TextStyle(color: isEnabled ? Colors.white : Colors.white24, fontWeight: FontWeight.bold)),
          ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: goldAccent, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: goldAccent)),
      ),
    );
  }
}