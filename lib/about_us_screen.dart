import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

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
          "ABOUT US",
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: goldAccent,
          ),
        ),
        iconTheme: IconThemeData(color: goldAccent),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24), // Keep side padding
        child: Column(
          children: [
            // --- ADDED PADDING FROM TOP ---
            const SizedBox(height: 30), 

            // --- FOUNDER IMAGES SECTION ---
            Row(
              children: [
                Expanded(child: _buildFounderImage("JAS SIR", "http://samandjas.com/api/test_uploads/jas.jpg")),
                const SizedBox(width: 15),
                Expanded(child: _buildFounderImage("SAM MA'AM", "http://samandjas.com/api/test_uploads/sam.jpg")),
              ],
            ),
            const SizedBox(height: 40),

            Center(
              child: Text(
                "SAM & JAS",
                style: GoogleFonts.cinzel(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: goldAccent,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "HAIR & MAKEUP ACADEMY",
              style: GoogleFonts.montserrat(
                fontSize: 12, color: Colors.white54, letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 30),

            _buildFounderProfile(
              "JAS SIR",
              "Founder & Technical Director",
              "With over 24 years of experience, Jas Sir is an epitome of creativity in Hair Styling. Trained at world-class institutes like Toni & Guy and Vidal Sassoon, he has led Sam & Jas to become a leading chain of salons and academies across India.",
            ),
            
            const SizedBox(height: 20),

            _buildFounderProfile(
              "SAM MA'AM",
              "Founder & Creative Director",
              "Boasting 20 years of mastery in Hair & Makeup, Sam Ma'am has worked with top industry artists and leading celebrities. Her goal is to spread professional knowledge to every corner of the country at an affordable price.",
            ),

            const SizedBox(height: 30),
            _buildStatSection(),
            const SizedBox(height: 30),

            Text(
              "Our mission is to empower aspiring artists with international standard skills, innovation, and industry trends, ensuring they thrive in the competitive world of beauty.",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white70, fontSize: 14, height: 1.6, fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildFounderImage(String name, String url) {
  return Column(
    children: [
      Container(
        height: 180,
        width: double.infinity,
        clipBehavior: Clip.antiAlias, // Ensures the image respects the border radius
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: goldAccent.withOpacity(0.3), width: 1.5),
          color: cardGrey, // Background color while loading
        ),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          // This is the "Magic" line - it anchors the image to the top
          alignment: const Alignment(0, -0.8), // Adjust between -1.0 (top) and 0.0 (center)
          errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: goldAccent, size: 50),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        name,
        style: GoogleFonts.montserrat(
          color: goldAccent, 
          fontSize: 12, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 1,
        ),
      ),
    ],
  );
}

  // ... (Keep _buildFounderProfile, _buildStatSection, and _buildStatItem as they were)
  Widget _buildFounderProfile(String name, String title, String bio) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardGrey,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: goldAccent.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.montserrat(color: goldAccent, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: GoogleFonts.montserrat(color: goldAccent.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            bio,
            style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem("500+", "Workshops"),
        _buildStatItem("2010", "Established"),
        _buildStatItem("5", "Own Branches"),
      ],
    );
  }

  Widget _buildStatItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.montserrat(color: goldAccent, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}