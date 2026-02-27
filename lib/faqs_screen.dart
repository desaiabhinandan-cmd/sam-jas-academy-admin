import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FaqsScreen extends StatelessWidget {
  const FaqsScreen({super.key});

  final Color goldAccent = const Color(0xFFD4A373);
  final Color charcoalBg = const Color(0xFF121212);
  final Color cardGrey = const Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: charcoalBg,
      appBar: AppBar(
        backgroundColor: charcoalBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "FAQ'S",
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: goldAccent,
          ),
        ),
        iconTheme: IconThemeData(color: goldAccent),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildCategoryHeader("General"),
          _buildFaqItem(
            "What courses do you offer?",
            "We offer professional courses in Professional Makeup, Hair Styling, and Skin Care, ranging from beginner to advanced levels.",
          ),
          _buildFaqItem(
            "Will I get a certificate?",
            "Yes, upon successful completion of the course and final assessment, you will receive a Sam and Jas Hair & Makeup Academy professional certificate.",
          ),
          const SizedBox(height: 20),
          _buildCategoryHeader("Payments & Access"),
          _buildFaqItem(
            "How can I pay for a course?",
            "You can pay directly through the app using UPI, Credit/Debit cards, or Net Banking.",
          ),
          _buildFaqItem(
            "Can I access courses offline?",
            "Currently, an active internet connection is required to stream the high-quality educational videos.",
          ),
          const SizedBox(height: 20),
          _buildCategoryHeader("Support"),
          _buildFaqItem(
            "How do I contact my trainer?",
            "You can use the WhatsApp Support button in your profile section to reach out to our dedicated student support team.",
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              "Still have questions?\nReach out to us via WhatsAppSupport",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: goldAccent.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldAccent.withOpacity(0.1)),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: goldAccent,
          collapsedIconColor: Colors.white54,
          title: Text(
            question,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: GoogleFonts.montserrat(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}