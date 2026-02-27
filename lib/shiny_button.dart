import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RegistrationShinyButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  const RegistrationShinyButton({super.key, required this.text, required this.onPressed});

  @override
  State<RegistrationShinyButton> createState() => _RegistrationShinyButtonState();
}

class _RegistrationShinyButtonState extends State<RegistrationShinyButton> with SingleTickerProviderStateMixin {
  late AnimationController _aniController;

  @override
  void initState() {
    super.initState();
    _aniController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _aniController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _aniController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), // Match the Send OTP button radius
            gradient: LinearGradient(
              begin: Alignment(-2.0 + (_aniController.value * 4), -1.0),
              end: Alignment(-1.0 + (_aniController.value * 4), 1.0),
              colors: const [Color(0xFF4A342B), Color(0xFF7D5D52), Color(0xFF4A342B)],
              stops: const [0.4, 0.5, 0.6],
            ),
          ),
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              widget.text.toUpperCase(), // Reverted to Uppercase
              style: GoogleFonts.montserrat(
                color: Colors.white, 
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }
}