import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'learning_player_screen.dart';
import 'pdf_viewer_screen.dart'; 

class MyCoursesScreen extends StatelessWidget {
  final Color goldAccent = const Color(0xFFD4A373);
  final Color darkBg = const Color(0xFF0F0F0F);

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    // --- UPDATED: Track Presence when they visit the Library ---
    _updateLastActivity(uid);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: goldAccent, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "MY LIBRARY",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1.2,
            color: goldAccent,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || userSnapshot.data!.data() == null) {
            return _buildEmptyLibrary(context);
          }

          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
          List enrolledIds = userData['enrolledCourses'] ?? [];
          List finishedLessons = userData['completedLessons'] ?? [];
          Map<String, dynamic> subscriptions = userData['subscriptions'] ?? {};

          if (enrolledIds.isEmpty) {
            return _buildEmptyLibrary(context);
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('courses')
                .where(FieldPath.documentId, whereIn: enrolledIds)
                .snapshots(),
            builder: (context, courseSnapshot) {
              if (!courseSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: courseSnapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var courseDoc = courseSnapshot.data!.docs[index];
                  String courseId = courseDoc.id;

                  String validityText = "Valid Access";
                  bool isExpired = false;
                  if (subscriptions.containsKey(courseId)) {
                    Timestamp expiryTs = subscriptions[courseId]['expiryDate'];
                    DateTime expiryDate = expiryTs.toDate();
                    int daysLeft = expiryDate.difference(DateTime.now()).inDays;

                    if (daysLeft <= 0) {
                      validityText = "Expired";
                      isExpired = true;
                    } else {
                      validityText = "$daysLeft Days Left";
                    }
                  }

                  return CourseCard(
                    data: courseDoc.data() as Map<String, dynamic>,
                    id: courseId,
                    finishedList: finishedLessons,
                    validity: validityText,
                    isExpired: isExpired,
                    goldAccent: goldAccent,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _updateLastActivity(String uid) {
    FirebaseFirestore.instance.collection('users').doc(uid).set({
      'lastActivity': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Widget _buildEmptyLibrary(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, color: Colors.white10, size: 80),
          const SizedBox(height: 16),
          Text("No courses enrolled yet.", style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}

class CourseCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String id;
  final List finishedList;
  final String validity;
  final bool isExpired;
  final Color goldAccent;

  const CourseCard({
    Key? key,
    required this.data,
    required this.id,
    required this.finishedList,
    required this.validity,
    required this.isExpired,
    required this.goldAccent,
  }) : super(key: key);

  @override
  _CourseCardState createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  bool isExpanded = false; 
  final Color cardColor = const Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final String? pdfUrl = widget.data['theoryPdfUrl'];
    final bool hasPdf = pdfUrl != null && pdfUrl.isNotEmpty;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.id)
          .collection('lessons')
          .snapshots(),
      builder: (context, lessonSnapshot) {
        int totalLessons = lessonSnapshot.hasData ? lessonSnapshot.data!.docs.length : 0;
        int completedInThisCourse = 0;

        if (lessonSnapshot.hasData) {
          var courseLessonIds = lessonSnapshot.data!.docs.map((d) => d.id).toList();
          completedInThisCourse = widget.finishedList
              .where((lessonId) => courseLessonIds.contains(lessonId))
              .length;
        }

        double progress = (totalLessons > 0) ? (completedInThisCourse / totalLessons) : 0.0;
        bool isDone = progress >= 1.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isExpired
                  ? Colors.red.withOpacity(0.5)
                  : (isDone ? Colors.green.withOpacity(0.3) : widget.goldAccent.withOpacity(0.1)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.isExpired ? () {} : () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LearningPlayerScreen(courseId: widget.id, courseTitle: widget.data['title'])),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
                        widget.data['thumbnailUrl'] ?? 'https://via.placeholder.com/400x200',
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(10)),
                        child: Text(widget.data['duration']?.toString() ?? "0 Hours", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: widget.isExpired ? Colors.red : Colors.black87, borderRadius: BorderRadius.circular(10)),
                        child: Text(widget.validity, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.data['category']?.toUpperCase() ?? "COURSE",
                          style: TextStyle(
                            color: widget.goldAccent.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        if (hasPdf && !widget.isExpired)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => PDFViewerScreen(
                                  url: pdfUrl!, 
                                  title: widget.data['title']?.toUpperCase() ?? "THEORY NOTES",
                                ),
                              ));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: widget.goldAccent, width: 1.5),
                                borderRadius: BorderRadius.circular(4), 
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.menu_book_rounded, size: 12, color: widget.goldAccent),
                                  const SizedBox(width: 6),
                                  Text(
                                    "VIEW THEORY",
                                    style: GoogleFonts.montserrat(
                                      color: widget.goldAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    Text(
                      widget.data['title'] ?? "Untitled Course",
                      style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    
                    const SizedBox(height: 10),
                    Text(
                      widget.data['description']?.toString() ?? "No Description",
                      maxLines: isExpanded ? 100 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.6),
                    ),
                    
                    InkWell(
                      onTap: () => setState(() => isExpanded = !isExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          isExpanded ? "SHOW LESS -" : "READ MORE +",
                          style: GoogleFonts.montserrat(
                            color: widget.goldAccent,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${(progress * 100).toInt()}% Complete", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        Text("$completedInThisCourse/$totalLessons Lessons", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearPercentIndicator(
                      padding: EdgeInsets.zero,
                      lineHeight: 4.0,
                      percent: progress > 1.0 ? 1.0 : progress,
                      barRadius: const Radius.circular(10),
                      progressColor: isDone ? Colors.greenAccent : widget.goldAccent,
                      backgroundColor: Colors.white.withOpacity(0.05),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isExpired ? Colors.grey : widget.goldAccent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: widget.isExpired ? null : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => LearningPlayerScreen(
                              courseId: widget.id, 
                              courseTitle: widget.data['title']
                            )),
                          );
                        },
                        child: Text(
                          isDone ? "REWATCH COURSE" : "CONTINUE LEARNING",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1.1,
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
      },
    );
  }
}