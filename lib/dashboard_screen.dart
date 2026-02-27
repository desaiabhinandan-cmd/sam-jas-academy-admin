import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'onboarding_screen.dart'; 
import 'registration_screen.dart'; 

import 'youtube_viewer.dart';
import 'profile_screen.dart';
import 'course_list_screen.dart';
import 'cart_screen.dart'; 
import 'profile_avatar.dart'; 
import 'notification_screen.dart';
import 'zoom_view.dart'; 
import 'live_hub_screen.dart'; // Added this import

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Color goldAccent = Color(0xFFD4A373);
  final Color charcoalBg = Color(0xFF121212);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> userEnrolledCourseIds = []; 

  @override
  void initState() {
    super.initState();
    _verifyUserAndDevice();
    _updateUserPresence();
    Future.delayed(Duration(seconds: 2), () {
      _syncPurchasedSubscriptions(); 
    });
  }

  Future<void> _syncPurchasedSubscriptions() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseMessaging.instance.subscribeToTopic('all_students');
        
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final List<dynamic> enrolled = data['enrolledCourses'] ?? [];
          
          setState(() {
            userEnrolledCourseIds = enrolled.cast<String>();
          });

          final allCoursesSnapshot = await FirebaseFirestore.instance.collection('courses').get();
          
          for (var doc in allCoursesSnapshot.docs) {
            String courseId = doc.id;
            String sanitized = courseId.trim().replaceAll(' ', '_');
            String topicName = 'course_$sanitized';

            if (userEnrolledCourseIds.contains(courseId)) {
              await FirebaseMessaging.instance.subscribeToTopic(topicName);
              debugPrint("✅ Subscribed to: $topicName");
            } else {
              await FirebaseMessaging.instance.unsubscribeFromTopic(topicName);
              debugPrint("🧹 Unsubscribed from: $topicName");
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  void _showDebugSnack(String message, Color color) {}

  Future<void> _updateUserPresence() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'lastActivity': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Presence Update Error: $e");
    }
  }

  Future<void> _verifyUserAndDevice() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RegistrationScreen()),
        );
      }
      return;
    }

    final data = userDoc.data() as Map<String, dynamic>;
    final String? registeredId = data['registeredDeviceId'];

    if (registeredId != null) {
      var deviceInfo = DeviceInfoPlugin();
      String? currentId = Platform.isAndroid 
          ? (await deviceInfo.androidInfo).id 
          : (await deviceInfo.iosInfo).identifierForVendor;

      if (registeredId != currentId) {
        await _auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Access Denied: Account is already linked to another device."),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      }
    }
  }

  TextStyle montStyle({double size = 14, FontWeight weight = FontWeight.normal, Color color = Colors.white}) {
    return GoogleFonts.montserrat(fontSize: size, fontWeight: weight, color: color);
  }

  @override
  Widget build(BuildContext context) {
    String uid = _auth.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: charcoalBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: charcoalBg,
            elevation: 0,
            centerTitle: false,
            title: Text.rich(
  TextSpan(
    style: GoogleFonts.cinzel(
      fontWeight: FontWeight.bold,
      color: goldAccent,
      letterSpacing: 2.0,
    ),
    children: [
      const TextSpan(
        text: "SAM ",
        style: TextStyle(fontSize: 22),
      ),
      WidgetSpan(
        alignment: PlaceholderAlignment.middle, // This centers it vertically
        child: Text(
          "AND ",
          style: GoogleFonts.cinzel(
            fontSize: 12, // Smaller size
            fontWeight: FontWeight.bold,
            color: goldAccent,
            letterSpacing: 2.0,
          ),
        ),
      ),
      const TextSpan(
        text: "JAS",
        style: TextStyle(fontSize: 22),
      ),
    ],
  ),
),
            actions: [
              // Updated Live Sessions Logic
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('live_sessions')
                    .where('isLive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  // Check if any of the live sessions are in the user's enrolled list
                  final userLiveDocs = snapshot.data!.docs.where((doc) {
                    return userEnrolledCourseIds.contains(doc.id);
                  }).toList();

                  if (userLiveDocs.isEmpty) return const SizedBox.shrink();

                  // Redirect to the Hub so they can choose which live session to join
                  return _ZoomPulseIcon(
                    isLive: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LiveHubScreen(),
                        ),
                      );
                    },
                  );
                },
              ),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('notifications')
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  int notifyCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications_none_outlined, color: goldAccent, size: 26),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NotificationScreen()),
                          );
                        },
                      ),
                      if (notifyCount > 0)
                        Positioned(
                          right: 8,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: charcoalBg, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                            child: Text(
                              '$notifyCount',
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('cart')
                    .snapshots(),
                builder: (context, snapshot) {
                  int cartCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.shopping_cart_outlined, color: goldAccent, size: 24),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CartScreen()),
                          );
                        },
                      ),
                      if (cartCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: charcoalBg, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$cartCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String? profileImageUrl;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    var userData = snapshot.data!.data() as Map<String, dynamic>?;
                    profileImageUrl = userData?['profileImageUrl'];
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0, left: 8.0),
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ProfileScreen()),
                          );
                        },
                        child: ProfileAvatar(
                          imageUrl: (profileImageUrl == null || profileImageUrl.isEmpty) ? "" : profileImageUrl, 
                          radius: 16, 
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          SliverToBoxAdapter(child: _buildSectionHeader("Our Courses")),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('categories')
                .orderBy('order')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return SliverToBoxAdapter(child: SizedBox());
              if (!snapshot.hasData) return SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              final docs = snapshot.data!.docs;
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildCategoryCard(data['name'] ?? 'COURSE', data['imageUrl'] ?? '');
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),

          SliverToBoxAdapter(child: _buildSectionHeader("Free Educational Videos")),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(left: 16),
                children: [
                  _buildFreeClassCard("Corrective Makeup Demo", "e4RcmNxNPdY"),
                  _buildFreeClassCard("Pro Brush Kit Guide", "UlrYNjN16R8"),
                  _buildFreeClassCard("Butterfly Hair Cut", "oI9-cNdh4Mw"),
                  _buildFreeClassCard("Maximum Layers Cut", "0jNn1WuOn58"),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: _buildSectionHeader("Celebrity Reviews")),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildYouTubeCard("Celebrity Testimonials","Sam & Jas Academy • Success Stories","9ulqZ756OrI","https://img.youtube.com/vi/9ulqZ756OrI/maxresdefault.jpg"),
              _buildYouTubeCard("Upasana Singh Makeover", "Sam & Jas Academy • 17K views", "Uo8hKgw_cck", "https://img.youtube.com/vi/Uo8hKgw_cck/maxresdefault.jpg"),
              _buildYouTubeCard("SAM Ma'am Interview by AKASA", "Sam & Jas Academy • 6.4K views", "yBYtD-gsPTs", "https://img.youtube.com/vi/yBYtD-gsPTs/maxresdefault.jpg"),
              
              
            ]),
          ),
          
          SliverToBoxAdapter(child: SizedBox(height: 5)),

          SliverToBoxAdapter(child: _buildSectionHeader("Student Feedback")),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildYouTubeCard(
  "Academy Certification Day", 
  "Sam & Jas Academy • Students Success", 
  "XqN7O8MTWB0", 
  "https://img.youtube.com/vi/XqN7O8MTWB0/maxresdefault.jpg"
),
_buildYouTubeCard(
  "Makeup Online Class Feedback", 
  "Sam & Jas Academy • Students Speak", 
  "pw87h6k_nqA", 
  "https://img.youtube.com/vi/pw87h6k_nqA/maxresdefault.jpg"
),
  _buildYouTubeCard(
  "Student Success Stories", 
  "Sam & Jas Academy • Heartfelt Feedback", 
  "LZWDhlnapO0", 
  "https://img.youtube.com/vi/LZWDhlnapO0/maxresdefault.jpg"
),
              
            ]),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 25, 16, 12),
      child: Text(title, style: montStyle(size: 18, weight: FontWeight.w700, color: goldAccent)),
    );
  }

  Widget _buildCategoryCard(String title, String imgUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => CourseListScreen(categoryName: title)));
      },
      child: Container(
        height: 140,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          image: DecorationImage(
            image: NetworkImage(imgUrl), 
            fit: BoxFit.cover, 
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
          ),
        ),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: 20),
        child: Text(title, style: montStyle(size: 22, weight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildFreeClassCard(String title, String videoId) {
    final String thumbUrl = "https://img.youtube.com/vi/$videoId/hqdefault.jpg";
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => YoutubeViewer(videoId: videoId)));
      },
      child: Container(
        width: 280,
        margin: EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(image: NetworkImage(thumbUrl), fit: BoxFit.cover),
        ),
        child: Stack(
          children: [
            Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(colors: [Colors.black.withOpacity(0.7), Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter))),
            Center(child: Icon(Icons.play_circle_outline, color: goldAccent, size: 50)),
            Positioned(bottom: 12, left: 12, right: 12, child: Text(title, style: montStyle(size: 14, weight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildYouTubeCard(String title, String subtitle, String videoId, String thumbUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => YoutubeViewer(videoId: videoId)));
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: NetworkImage(thumbUrl), fit: BoxFit.cover)),
                child: Center(child: Icon(Icons.play_arrow, color: Colors.white, size: 60)),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                // Change this line inside _buildYouTubeCard:
              ProfileAvatar(imageUrl: "https://yt3.ggpht.com/ytc/AIdro_mlB_xO88mCfK-SSV6l8sUR_y5eK0XNj7li1p97FUX1Sg=s48-c-k-c0x00ffffff-no-rj", radius: 18, fontSize: 12),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: montStyle(size: 14, weight: FontWeight.bold)),
                      Text(subtitle, style: montStyle(size: 12, color: Colors.white60)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomPulseIcon extends StatefulWidget {
  final bool isLive;
  final VoidCallback onTap;
  const _ZoomPulseIcon({required this.isLive, required this.onTap});

  @override
  State<_ZoomPulseIcon> createState() => _ZoomPulseIconState();
}

class _ZoomPulseIconState extends State<_ZoomPulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLive) return const SizedBox.shrink();
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: IconButton(
        icon: const Icon(Icons.videocam, color: Colors.blueAccent, size: 28),
        onPressed: widget.onTap,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}