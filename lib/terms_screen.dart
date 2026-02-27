import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
          "TERMS & CONDITIONS",
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
            
            _buildSection("1. Acceptance of Terms", 
              "By accessing and using the Sam & Jas Academy app, you agree to be bound by these Terms and Conditions. If you do not agree, please refrain from using the application."),
            
            // --- UPDATED PROTECTION CLAUSE ---
            _buildSection("2. Intellectual Property & Anti-Piracy", 
              "All course materials, including video lessons, live streams, PDFs, and images, are the exclusive property of Sam & Jas Academy. \n\n"
              "• RECORDING PROHIBITED: Screen recording, capturing, or downloading videos via third-party software is strictly forbidden.\n"
              "• DISTRIBUTION PROHIBITED: Sharing, reselling, or uploading academy content to social media, YouTube, or file-sharing platforms is a direct violation of copyright law.\n"
              "• LEGAL ACTION: Any user found distributing or recording content will have their account terminated immediately without refund and will be liable for legal prosecution and financial damages."),
            
            _buildSection("3. Single Device Policy", 
              "Access is granted for personal use only. Your account is tied to a single registered device. Simultaneous login or sharing of credentials will result in an automatic account lock."),
            
            _buildSection("4. Refund Policy", 
              "Due to the digital nature of our educational content, all fees paid are non-refundable. We encourage students to view free demo videos before making a purchase."),
            
            _buildSection("5. Certificate Issuance", 
              "Certificates are only issued to students who complete the full course duration and pass the required practical or theoretical assessments as defined by the Academy."),
            
            const SizedBox(height: 30),
            Center(
              child: Text(
                "© 2026 Sam & Jas Academy. All rights reserved.",
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