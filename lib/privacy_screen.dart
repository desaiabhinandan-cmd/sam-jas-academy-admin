import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  final Color goldAccent = const Color(0xFFD4A373);
  final Color charcoalBg = const Color(0xFF121212);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: charcoalBg,
      appBar: AppBar(
        backgroundColor: charcoalBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "PRIVACY POLICY",
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: goldAccent,
          ),
        ),
        iconTheme: IconThemeData(color: goldAccent),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Last Updated: February 2026",
              style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 25),
            
            _buildSection("1. Information We Collect", 
              "We collect information to provide a secure and personalized learning experience. This includes:\n"
              "• Personal Identity: Full Name, Email, and Phone Number verified via OTP.\n"
              "• Media: Profile images uploaded by the user to our secure Windows server.\n"
              "• Device Security: Unique Device Hardware IDs to strictly enforce our single-device login policy.\n"
              "• Academic Progress: Course completion status, assessment scores, and payment history."),
            
            _buildSection("2. How We Use Your Data", 
              "Your information is used strictly for:\n"
              "• Granting access to paid course content.\n"
              "• Generating authentic professional certificates with your registered name.\n"
              "• Preventing unauthorized content distribution or account sharing.\n"
              "• Providing direct support via WhatsApp and Voice Call channels."),
            
            _buildSection("3. Data Storage & Security", 
              "We take your privacy seriously:\n"
              "• Your authentication is handled securely by Firebase (Google).\n"
              "• Your profile images are stored on our private, dedicated Windows server at samandjas.com.\n"
              "• We do not sell or share your personal contact details with third-party advertisers."),
            
            _buildSection("4. Intellectual Property Monitoring", 
              "To protect the Academy's intellectual property, the app monitors for unauthorized screen recording or capturing while course videos are active. No personal data from your device's gallery or other apps is accessed during this process."),
            
            _buildSection("5. Your Rights & Data Deletion", 
              "You have the right to access your data or request account deletion. If you wish to delete your account and all associated records from our server and Firebase, please contact Sam & Jas Academy support through the 'Contact Us' section."),
            
            const SizedBox(height: 30),
            Center(
              child: Text(
                "Your privacy and trust are the foundation of Sam & Jas Academy.",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: Colors.white24, fontSize: 11),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              color: goldAccent,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.montserrat(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}