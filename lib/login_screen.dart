import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io'; // Added for Platform check
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart'; // Added for Device ID
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final Color espresso = const Color(0xFF4A342B);
  final Color caramel = const Color(0xFFD4A373);
  final Color cream = const Color(0xFFFFFDF1);

  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  // --- NEW: Helper to get Unique Device ID ---
  Future<String> _getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      var iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "unknown_ios";
    } else {
      var androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // Unique hardware ID for Android
    }
  }

  Future<void> _sendOTP() async {
    final String phone = _phoneController.text.trim();
    if (phone.length < 10) return;

    setState(() => _isLoading = true);

    // 1. Generate local 6-digit OTP
    var rng = Random();
    String generatedOtp = (rng.nextInt(900000) + 100000).toString();

    try {
      // --- NEW: Capture Device ID before proceeding ---
      String deviceId = await _getDeviceId();

      final String apiBase = "http://samandjas.com/api";
      final url = Uri.parse("$apiBase/send-sms?phone=$phone&otp=$generatedOtp&name=User");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        String? firebaseToken;

        try {
          final Map<String, dynamic> responseData = json.decode(response.body);
          firebaseToken = responseData['token'];
        } catch (e) {
          firebaseToken = response.body.trim();
        }
        
        setState(() => _isLoading = false);
        
        if (!mounted) return;

        if (firebaseToken != null && firebaseToken.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPScreen(
                phoneNumber: "+91 $phone",
                serverOtp: generatedOtp, 
                customToken: firebaseToken, 
                // deviceId: deviceId, // Ensure your OTPScreen constructor accepts this!
              ),
            ),
          );
        } else {
          throw Exception("Authentication failed: No token received.");
        }
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text(
                "Login or Register",
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: espresso,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter your mobile number to continue",
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: espresso.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: caramel.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Text(
                        "+91",
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          color: espresso,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: GoogleFonts.montserrat(color: espresso, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          hintText: "Phone Number",
                          counterText: "",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: espresso))
                  : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _sendOTP,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: espresso,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "SEND OTP",
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 50),
              Center(
                child: Column(
                  children: [
                    Text(
                      "By continuing, you agree to our",
                      style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Terms & Conditions & Privacy Policy",
                      style: GoogleFonts.montserrat(
                        fontSize: 11, 
                        color: espresso, 
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}