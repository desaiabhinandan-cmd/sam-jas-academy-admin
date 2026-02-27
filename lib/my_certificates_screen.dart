import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 
import 'certificate_service.dart';

class MyCertificatesScreen extends StatelessWidget {
  final Color goldAccent = const Color(0xFFD4A373);
  final Color darkCard = const Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: goldAccent, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "CERTIFICATES", 
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900, 
            fontSize: 14, 
            color: Colors.white,
            letterSpacing: 1.5
          )
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          var userData = userSnap.data!.data() as Map<String, dynamic>;
          
          // --- NAME PRIORITIZATION LOGIC ---
          String? customCertName = userData['nameOnCertificate'];
          String firstName = userData['firstName'] ?? '';
          String lastName = userData['lastName'] ?? '';
          
          String finalCertificateName = (customCertName != null && customCertName.trim().isNotEmpty)
              ? customCertName.trim()
              : "$firstName $lastName".trim();

          if (finalCertificateName.isEmpty) finalCertificateName = "STUDENT NAME";

          List enrolledIds = userData['enrolledCourses'] ?? [];
          List completedLessons = userData['completedLessons'] ?? [];
          String? profileImg = userData['profileImageUrl']; 
          Map<String, dynamic> subscriptions = userData['subscriptions'] ?? {};

          if (enrolledIds.isEmpty) {
            return Center(child: Text("Complete your courses to earn certificates.", 
              style: GoogleFonts.montserrat(color: Colors.white24, fontSize: 12)));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: enrolledIds.length,
            itemBuilder: (context, index) {
              String courseId = enrolledIds[index];
              
              dynamic rawDate = subscriptions[courseId]?['purchaseDate'];
              String joinDate = "N/A";
              if (rawDate != null) {
                  DateTime dt = (rawDate as Timestamp).toDate();
                  joinDate = DateFormat('MMM dd, yyyy').format(dt);
              }

              return CertificateValidator(
                courseId: courseId, 
                completedList: completedLessons, 
                userName: finalCertificateName, 
                joinDate: joinDate, 
                profileImg: profileImg,
                goldAccent: goldAccent,
                darkCard: darkCard,
              );
            },
          );
        },
      ),
    );
  }
}

class CertificateValidator extends StatelessWidget {
  final String courseId;
  final List completedList;
  final String userName;
  final String joinDate;
  final String? profileImg;
  final Color goldAccent;
  final Color darkCard;

  const CertificateValidator({
    required this.courseId,
    required this.completedList,
    required this.userName,
    required this.joinDate,
    required this.profileImg,
    required this.goldAccent,
    required this.darkCard,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .collection('lessons')
          .get(),
      builder: (context, lessonSnap) {
        if (!lessonSnap.hasData) return const SizedBox();

        int totalLessons = lessonSnap.data!.docs.length;
        var courseLessonIds = lessonSnap.data!.docs.map((d) => d.id).toList();
        int userDoneCount = completedList.where((id) => courseLessonIds.contains(id)).length;

        bool isEligible = (totalLessons > 0) && (userDoneCount >= totalLessons);

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('courses').doc(courseId).get(),
          builder: (context, courseSnap) {
            if (!courseSnap.hasData) return const SizedBox();
            var courseData = courseSnap.data!.data() as Map<String, dynamic>;

            return _buildCard(context, courseData, isEligible, userDoneCount, totalLessons);
          },
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> data, bool isEligible, int userDoneCount, int totalLessons) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEligible ? goldAccent.withOpacity(0.4) : Colors.white.withOpacity(0.05)
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Icon(
              isEligible ? Icons.verified_rounded : Icons.lock_person_outlined, 
              color: isEligible ? goldAccent : Colors.white10, 
              size: 30
            ),
            title: Text(
              (data['title'] ?? "Course").toUpperCase(), 
              style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isEligible ? "COMPLETED" : "IN PROGRESS ($userDoneCount/$totalLessons)", 
                style: TextStyle(color: isEligible ? Colors.greenAccent : Colors.white38, fontSize: 10, letterSpacing: 1)
              ),
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.05)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ENROLLED ON", 
                        style: TextStyle(color: Colors.white38, fontSize: 7, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        joinDate, 
                        style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: isEligible ? goldAccent : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                  child: InkWell(
                    onTap: isEligible ? () async {
                      if (profileImg == null || profileImg!.isEmpty) {
                        _showPhotoAlert(context);
                      } else {
                        // FIX: Ensure correct data field 'certificateTemplateUrl' is passed
                        await CertificateService.generateCertificate(
                          context: context,
                          userName: userName,
                          courseTitle: data['title'] ?? "Course",
                          templatePath: data['certificateTemplateUrl'] ?? "",
                          profileImageUrl: profileImg!,
                          enrollmentDate: joinDate,
                        );
                      }
                    } : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(
                        isEligible ? "DOWNLOAD CERTIFICATE" : "LOCKED", 
                        style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkCard,
        title: Text("Photo Required", style: GoogleFonts.montserrat(color: goldAccent, fontWeight: FontWeight.bold)),
        content: const Text("Please upload a profile photo in account settings to generate your certificate.", 
          style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("OK", style: TextStyle(color: goldAccent))),
        ],
      ),
    );
  }
}