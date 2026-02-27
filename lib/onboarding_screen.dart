import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;
  Timer? _timer;

  final List<Map<String, String>> _slides = [
    {"image": "assets/images/slide1_new.png", "desc": "Master professional skills with industry experts."},
    {"image": "assets/images/slide2.png", "desc": "Experience 23 years of excellence in professional coaching."},
    {"image": "assets/images/slide3.png", "desc": "Join a community of creative hair and makeup artists."},
    {"image": "assets/images/slide4.png", "desc": "Advance your career with certified professional modules."},
    {"image": "assets/images/slide1.png", "desc": "Start your journey at the Sam & Jas Academy today."},
  ];

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentIndex < _slides.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0; 
      }
      if (_controller.hasClients) {
        _controller.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                  child: Text(
                    "SKIP",
                    style: GoogleFonts.montserrat(
                      color: const Color(0xFF4A342B), 
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                    _startAutoPlay(); 
                  },
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(_slides[index]['image']!, height: 260),
                        const SizedBox(height: 50),
                        
                        // BRANDING SECTION: Ultra Wide & Balanced
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "SAM", 
                                    style: GoogleFonts.cinzel(
                                      fontSize: 42, 
                                      fontWeight: FontWeight.bold, 
                                      color: const Color(0xFF4A342B),
                                      letterSpacing: 8, // ULTRA WIDE
                                    )
                                  ),
                                  const SizedBox(width: 15),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      "AND", 
                                      style: GoogleFonts.cinzel(
                                        fontSize: 14, 
                                        fontWeight: FontWeight.bold, 
                                        color: const Color(0xFF4A342B),
                                        letterSpacing: 4,
                                      )
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Text(
                                    "JAS", 
                                    style: GoogleFonts.cinzel(
                                      fontSize: 42, 
                                      fontWeight: FontWeight.bold, 
                                      color: const Color(0xFF4A342B),
                                      letterSpacing: 8, // ULTRA WIDE
                                    )
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "HAIR & MAKEUP",
                                style: GoogleFonts.montserrat(
                                  letterSpacing: 10, // MATCHING THE WIDTH
                                  fontSize: 11, 
                                  color: const Color(0xFF1E1411), // EXTRA DARK
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "ACADEMY",
                                style: GoogleFonts.cinzel(
                                  fontSize: 22, 
                                  letterSpacing: 14, // ULTRA WIDE
                                  fontWeight: FontWeight.w600, 
                                  color: const Color(0xFF4A342B)
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 45),
                          child: Text(
                            _slides[index]['desc']!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              color: Colors.grey[800], 
                              fontSize: 13, 
                              height: 1.7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              
              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  height: 6,
                  width: _currentIndex == index ? 24 : 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == index ? const Color(0xFF4A342B) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                )),
              ),
              
              Padding(
                padding: const EdgeInsets.all(35.0),
                child: ShinyButton(
                  text: _currentIndex == _slides.length - 1 ? "GET STARTED" : "NEXT",
                  onPressed: () {
                    if (_currentIndex == _slides.length - 1) {
                      Navigator.pushReplacement(
                        context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                    } else {
                      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShinyButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  const ShinyButton({super.key, required this.text, required this.onPressed});

  @override
  State<ShinyButton> createState() => _ShinyButtonState();
}

class _ShinyButtonState extends State<ShinyButton> with SingleTickerProviderStateMixin {
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
          width: double.infinity, height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
              widget.text,
              style: GoogleFonts.montserrat(
                color: Colors.white, 
                fontWeight: FontWeight.bold, 
                letterSpacing: 2.0,
              ),
            ),
          ),
        );
      },
    );
  }
}