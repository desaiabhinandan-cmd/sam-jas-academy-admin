import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final double fontSize;
  final Color goldAccent = const Color(0xFFD4A373);

  const ProfileAvatar({
    Key? key, 
    this.imageUrl, 
    this.radius = 25, 
    this.fontSize = 18
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. Determine if the image is actually usable
    bool hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty && imageUrl!.startsWith('http');

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: goldAccent, width: 1.5),
      ),
      child: hasImage 
        ? CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF1E1E1E),
            backgroundImage: NetworkImage(imageUrl!), // Only called if hasImage is true
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF1E1E1E),
            child: Text(
              "SJ",
              style: GoogleFonts.montserrat(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: goldAccent,
                letterSpacing: 1,
              ),
            ),
          ),
    );
  }
}