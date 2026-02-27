import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:in_app_review/in_app_review.dart'; 
import 'dart:io';

// Project Imports
import 'faqs_screen.dart';
import 'terms_screen.dart';
import 'about_us_screen.dart';
import 'login_screen.dart';
import 'my_courses_screen.dart';
import 'my_payments_screen.dart';
import 'my_certificates_screen.dart';
import 'registration_screen.dart';
import 'privacy_screen.dart';
import 'admin_broadcast_screen.dart'; 
import 'admin_coupon_screen.dart';
import 'admin_live_class_screen.dart';
import 'admin_category_screen.dart'; 
import 'admin_course_manager_screen.dart';
import 'admin_user_manager_screen.dart'; // ADDED: Import for User Manager

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color goldAccent = const Color(0xFFD4A373);
  final Color charcoalBg = const Color(0xFF121212);
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InAppReview _inAppReview = InAppReview.instance; 

  TextStyle montStyle({double size = 16, FontWeight weight = FontWeight.w500, Color color = Colors.white}) {
    return GoogleFonts.montserrat(fontSize: size, fontWeight: weight, color: color);
  }

  Future<void> _requestReview() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        _inAppReview.openStoreListing(
          appStoreId: '6741160359',
          microsoftStoreId: null,
        );
      }
    } catch (e) {
      const String packageName = "com.samjas.academy";
      Uri url = Platform.isAndroid 
          ? Uri.parse("market://details?id=$packageName")
          : Uri.parse("https://apps.apple.com/app/id6741160359");

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _launchSupport(String type) async {
    const String phoneNumber = "917718810536"; 
    Uri url;

    if (type == 'whatsapp') {
      url = Uri.parse("https://wa.me/$phoneNumber?text=Hello%20Sam%20%26%20Jas%20Academy%2C%20I%20need%20assistance%20with...");
    } else {
      url = Uri.parse("tel:+$phoneNumber");
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening $type"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: charcoalBg,
      appBar: AppBar(
        backgroundColor: charcoalBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "MY ACCOUNT",
          style: montStyle(size: 18, weight: FontWeight.bold, color: goldAccent),
        ),
        iconTheme: IconThemeData(color: goldAccent),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(_auth.currentUser?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: goldAccent));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("User data not found", style: montStyle()));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>?;

          String fName = userData?['firstName'] ?? "";
          String lName = userData?['lastName'] ?? "";
          String? profileImageUrl = userData?['profileImageUrl'];
          
          bool isAdmin = userData?['role'] == 'admin' || userData?['isAdmin'] == true;
          
          String fullName = "$fName $lName".trim();
          if (fullName.isEmpty) fullName = "Academy Student";

          String? versionedUrl;
          if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
            versionedUrl = "$profileImageUrl?v=${DateTime.now().millisecondsSinceEpoch}";
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildUserHeader(fullName, versionedUrl),
                const SizedBox(height: 30),

                // --- ADMIN SECTION ---
                if (isAdmin) ...[
                  _sectionLabel("Admin Tools"),
                  _buildMenuTile(Icons.campaign_rounded, "Send Broadcast Notification", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminBroadcastScreen()),
                    );
                  }),
                  _buildMenuTile(Icons.confirmation_number_outlined, "Coupon Manager", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminCouponScreen()),
                    );
                  }),
                  _buildMenuTile(Icons.video_camera_front_outlined, "Zoom Session Manager", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  AdminLiveClassScreen()),
                    );
                  }),
                  _buildMenuTile(Icons.category_outlined, "Category Manager", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  const AdminCategoryScreen()),
                    );
                  }),
                  _buildMenuTile(Icons.library_books_outlined, "Course Content Manager", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  const AdminCourseManagerScreen()),
                    );
                  }),
                  // ADDED: User Manager Tile
                  _buildMenuTile(Icons.people_alt_outlined, "User Manager", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminUserManagerScreen()),
                    );
                  }),
                  const Divider(color: Colors.white10, indent: 20, endIndent: 20),
                ],

                _sectionLabel("Learning Hub"),
                _buildMenuTile(Icons.person_pin_outlined, "My Profile", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegistrationScreen(isFromDashboard: true)),
                  );
                }),
                _buildMenuTile(Icons.play_lesson_outlined, "My Courses", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>  MyCoursesScreen()),
                  );
                }),
                _buildMenuTile(Icons.receipt_long_outlined, "My Payments", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MyPaymentsScreen()),
                  );
                }),
                _buildMenuTile(Icons.workspace_premium_outlined, "My Certificates", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyCertificatesScreen()),
                  );
                }),

                const Divider(color: Colors.white10, indent: 20, endIndent: 20),

                _sectionLabel("Support"),
                _buildMenuTile(Icons.chat_outlined, "WhatsApp Support", () {
                  _launchSupport('whatsapp');
                }),
                _buildMenuTile(Icons.quiz_outlined, "FAQ's", () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => FaqsScreen()));
                }),
                _buildMenuTile(Icons.business_outlined, "About Us", () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AboutUsScreen()));
                }),
                _buildMenuTile(Icons.contact_support_outlined, "Contact Us", () {
                   _launchSupport('tel');
                }),

                const Divider(color: Colors.white10, indent: 20, endIndent: 20),

                _sectionLabel("Application"),
                _buildMenuTile(Icons.star_rate_outlined, "Rate Our App", () {
                  _requestReview();
                }),
                _buildMenuTile(Icons.policy_outlined, "Privacy Policy", () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacyScreen()));
                }),
                _buildMenuTile(Icons.assignment_outlined, "Terms & Conditions", () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => TermsScreen()));
                }),

                const SizedBox(height: 20),
                _buildMenuTile(
                  Icons.logout, 
                  "Logout", 
                  () async {
                    await _auth.signOut();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()), 
                      (Route<dynamic> route) => false,
                    );
                  },
                  isLogout: true,
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserHeader(String name, String? profileImageUrl) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: goldAccent, width: 2)),
          child: CircleAvatar(
            radius: 55,
            backgroundColor: const Color(0xFF1E1E1E),
            backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty) ? NetworkImage(profileImageUrl) : null,
            child: (profileImageUrl == null || profileImageUrl.isEmpty)
                ? Text("SJ", style: GoogleFonts.montserrat(fontSize: 40, fontWeight: FontWeight.w900, color: goldAccent, letterSpacing: 2))
                : null,
          ),
        ),
        const SizedBox(height: 15),
        Text(name, style: montStyle(size: 20, weight: FontWeight.bold)),
      ],
    );
  }

  Widget _sectionLabel(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(title.toUpperCase(), style: montStyle(size: 12, weight: FontWeight.bold, color: goldAccent.withOpacity(0.7))),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap, {bool isLogout = false}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: isLogout ? Colors.redAccent : goldAccent, size: 24),
      title: Text(title, style: montStyle(size: 15, color: isLogout ? Colors.redAccent : Colors.white)),
      trailing: isLogout ? null : const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
    );
  }
}
