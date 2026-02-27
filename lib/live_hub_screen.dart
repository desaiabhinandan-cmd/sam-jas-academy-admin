import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Ensure auth is imported to get UID

class LiveHubScreen extends StatelessWidget {
  const LiveHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current logged-in user ID
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          "JOIN LIVE SESSIONS",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD4A373),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: currentUserId == null
          ? const Center(child: Text("Please log in to view sessions", style: TextStyle(color: Colors.white)))
          : StreamBuilder<DocumentSnapshot>(
              // STEP 1: Listen to the User's Enrollment Data
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const Center(child: Text("User data not found", style: TextStyle(color: Colors.white38)));
                }

                // Get the enrolledCourses array from your screenshot
                List<dynamic> myEnrolledIds = userSnapshot.data!.get('enrolledCourses') ?? [];

                if (myEnrolledIds.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text(
                        "You are not enrolled in any courses yet.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  );
                }

                // STEP 2: Listen to all LIVE sessions
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('live_sessions')
                      .where('isLive', isEqualTo: true)
                      .snapshots(),
                  builder: (context, liveSnapshot) {
                    if (liveSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // STEP 3: Filter sessions locally
                    // Only show sessions where the Document ID exists in the user's enrolledCourses list
                    var myLiveSessions = liveSnapshot.data!.docs.where((doc) {
                      return myEnrolledIds.contains(doc.id);
                    }).toList();

                    if (myLiveSessions.isEmpty) {
                      return const Center(
                        child: Text(
                          "No live sessions for your courses.",
                          style: TextStyle(color: Colors.white38),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: myLiveSessions.length,
                      itemBuilder: (context, index) {
                        var session = myLiveSessions[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            title: Text(
                              session['courseName'] ?? "Live Class",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text("Happening Now", style: TextStyle(color: Colors.green)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _joinZoom(session['meetingId'], session['password']),
                              child: const Text("JOIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  void _joinZoom(String id, String pass) async {
    // Standard Zoom join URL format
    final Uri url = Uri.parse("https://zoom.us/j/$id?pwd=$pass");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch Zoom URL");
    }
  }
}