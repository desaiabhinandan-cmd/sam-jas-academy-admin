import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
// Internal viewer import - Ensure this file exists in your project
import 'pdf_viewer_screen.dart'; 
import 'course_detail_screen.dart';
import 'learning_player_screen.dart';

class CourseListScreen extends StatelessWidget {
  final String categoryName;
  final Color goldAccent = const Color(0xFFD4A373);
  final Color darkCanvas = const Color(0xFF0F0F0F);

  CourseListScreen({required this.categoryName});

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: darkCanvas,
      appBar: AppBar(
        backgroundColor: darkCanvas,
        elevation: 0,
        centerTitle: true,
        title: Text(
          categoryName.toUpperCase(),
          style: GoogleFonts.montserrat(
            color: goldAccent,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: goldAccent, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(includeMetadataChanges: true),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: goldAccent));
          }

          var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          
          Map<String, dynamic> subscriptions = {};
          if (userData != null && userData['subscriptions'] != null) {
            subscriptions = Map<String, dynamic>.from(userData['subscriptions']);
          }
          
          List completedLessonIds = userData?['completedLessons'] ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('courses')
                .where('category', isEqualTo: categoryName)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: goldAccent));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(); 
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var courseDoc = snapshot.data!.docs[index];
                  var courseData = courseDoc.data() as Map<String, dynamic>;
                  String docId = courseDoc.id;

                  bool isOwned = false;

                  if (subscriptions.containsKey(docId)) {
                    var subData = subscriptions[docId];
                    if (subData is Map) {
                      bool subActive = subData['isActive'] ?? false;
                      DateTime? expiry;

                      if (subData['expiryDate'] != null) {
                        if (subData['expiryDate'] is Timestamp) {
                          expiry = (subData['expiryDate'] as Timestamp).toDate();
                        } else if (subData['expiryDate'] is String) {
                          expiry = DateTime.tryParse(subData['expiryDate']);
                        }
                      }

                      if (subActive) {
                        if (expiry == null) {
                          isOwned = true; 
                        } else {
                          isOwned = DateTime.now().isBefore(expiry);
                        }
                      }
                    }
                  }

                  return CourseCard(
                    course: courseData,
                    id: docId,
                    isOwned: isOwned,
                    goldAccent: goldAccent,
                    userCompletedLessonIds: completedLessonIds,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: goldAccent.withOpacity(0.1), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: goldAccent.withOpacity(0.05),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_stories_outlined, 
                color: goldAccent.withOpacity(0.4),
                size: 50,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "CURATING CONTENT",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 4.0, 
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Our masterclass library is currently being updated with exclusive new lessons. Check back shortly.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
                height: 1.8,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              width: 30,
              height: 1,
              color: goldAccent.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class CourseCard extends StatefulWidget {
  final Map<String, dynamic> course;
  final String id;
  final bool isOwned;
  final Color goldAccent;
  final List userCompletedLessonIds;

  const CourseCard({
    required this.course,
    required this.id,
    required this.isOwned,
    required this.goldAccent,
    required this.userCompletedLessonIds,
  });

  @override
  _CourseCardState createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  bool isExpanded = false;

  // Updated to open inside the app via Navigator
  // Updated to match your exact class and parameter names
  void _openPdf(String url, String title) {
    if (url.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerScreen( // Matches your class name
            url: url,                          // Matches your 'url' parameter
            title: title,                      // Matches your 'title' parameter
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF not available for this course.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasPdf = widget.course['theoryPdfUrl'] != null && 
                  widget.course['theoryPdfUrl'].toString().trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isOwned ? widget.goldAccent.withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (widget.isOwned) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LearningPlayerScreen(
                  courseId: widget.id,
                  courseTitle: widget.course['title'] ?? "Learning",
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseDetailScreen(courseData: widget.course, courseId: widget.id),
              ),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    widget.course['thumbnailUrl'] ?? 'https://via.placeholder.com/400x220',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 15,
                  left: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      widget.course['duration'] ?? "",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (widget.isOwned)
                  Positioned(
                    top: 15,
                    right: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.goldAccent,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Colors.black),
                          const SizedBox(width: 4),
                          Text(
                            "ENROLLED",
                            style: GoogleFonts.montserrat(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course['title'] ?? "Untitled Course",
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.isOwned ? widget.goldAccent : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (widget.isOwned) _buildCourseProgress(),

                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isExpanded = !isExpanded;
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.course['description'] ?? "",
                          maxLines: isExpanded ? 10 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            color: Colors.white60, 
                            fontSize: 13, 
                            height: 1.4
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isExpanded ? "Show Less" : "Read More",
                          style: TextStyle(
                            color: widget.goldAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  if (widget.isOwned)
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: SizedBox(
                            height: 45,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.goldAccent,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => LearningPlayerScreen(
                                    courseId: widget.id, 
                                    courseTitle: widget.course['title'] ?? "Learning"
                                  )),
                                );
                              },
                              child: Text(
                                "CONTINUE LEARNING",
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (hasPdf) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 45,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: widget.goldAccent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: EdgeInsets.zero,
                                ),
                                // Pass URL and Title to internal viewer
                                onPressed: () => _openPdf(
                                  widget.course['theoryPdfUrl'],
                                  widget.course['title'] ?? "Course Notes"
                                ),
                                child: Icon(Icons.picture_as_pdf, color: widget.goldAccent),
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "₹${widget.course['price']}",
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: widget.goldAccent,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.goldAccent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: widget.goldAccent,
                            size: 18,
                          ),
                        )
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseProgress() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.id)
          .collection('lessons')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 20);

        final allLessons = snapshot.data!.docs;
        final totalCount = allLessons.length;
        final completedCount = allLessons
            .where((doc) => widget.userCompletedLessonIds.contains(doc.id))
            .length;

        double progressValue = totalCount > 0 ? completedCount / totalCount : 0.0;
        int percent = (progressValue * 100).toInt();

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$percent% COMPLETED",
                  style: GoogleFonts.montserrat(
                    color: widget.goldAccent, 
                    fontSize: 10, 
                    fontWeight: FontWeight.w800, 
                    letterSpacing: 1
                  ),
                ),
                Text(
                  "$completedCount/$totalCount LESSONS",
                  style: GoogleFonts.montserrat(
                    color: Colors.white54, 
                    fontSize: 10, 
                    fontWeight: FontWeight.w600
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.white.withOpacity(0.05),
                color: percent == 100 ? Colors.green : widget.goldAccent,
                minHeight: 4,
              ),
            ),
          ],
        );
      },
    );
  }
}