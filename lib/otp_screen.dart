import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:http/http.dart' as http; 
import 'package:smart_auth/smart_auth.dart'; 
import 'package:device_info_plus/device_info_plus.dart'; // Added for Device ID
import 'dart:io'; // Added for Platform check
import 'registration_screen.dart';
import 'dashboard_screen.dart'; 
import 'login_screen.dart'; 
import 'shiny_button.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String serverOtp; 
  final String? customToken; 

  const OTPScreen({
    super.key, 
    required this.phoneNumber, 
    required this.serverOtp,
    this.customToken 
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  
  final SmartAuth _smartAuth = SmartAuth();

  final Color espresso = const Color(0xFF4A342B);
  final Color caramel = const Color(0xFFD4A373);
  final Color cream = const Color(0xFFFFFDF1);

  String get _otpCode => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startSmsListener(); 
  }

  // --- NEW: Helper to fetch unique Handset ID ---
  Future<String> _getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      var iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "unknown_ios";
    } else {
      var androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; 
    }
  }

  @override
  void dispose() {
    _smartAuth.removeSmsListener(); 
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startSmsListener() async {
    try {
      final res = await _smartAuth.getSmsCode();
      if (res.succeed && res.code != null) {
        final code = res.code!;
        if (mounted) {
          setState(() {
            for (int i = 0; i < code.length && i < 6; i++) {
              _controllers[i].text = code[i];
            }
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            _verifyOTP();
          });
        }
      }
    } catch (e) {
      debugPrint("SMS Listener Error: $e");
    }
  }

  Future<void> _resendOTP() async {
    final String cleanPhone = widget.phoneNumber.replaceAll("+91", "").replaceAll(" ", "").trim();
    _startSmsListener(); 
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Resending OTP via SMS..."), duration: Duration(seconds: 1)),
    );
    try {
      final String apiBase = "http://samandjas.com/api";
      final url = Uri.parse("$apiBase/send-sms?phone=$cleanPhone&otp=${widget.serverOtp}&name=User");
      final response = await http.get(url); 
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("OTP Sent Successfully!"), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception("Failed to resend: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) _showError("Failed to resend OTP.");
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpCode.length < 6) {
      _showError("Please enter all 6 digits.");
      return;
    }
    
    setState(() => _isVerifying = true);

    if (_otpCode.trim() == widget.serverOtp.toString().trim()) {
      try {
        if (widget.customToken != null && widget.customToken!.isNotEmpty) {
          // 1. Authenticate with Firebase
          await FirebaseAuth.instance.signInWithCustomToken(widget.customToken!);
          
          // 2. Format Phone Number to match your Firestore Doc ID (UID)
          String phoneDocId = widget.phoneNumber.replaceAll("+91", "").replaceAll(" ", "").trim();
          
          // 3. Get Handset ID and Firestore Record
          String currentDeviceId = await _getDeviceId();
          DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(phoneDocId).get();

          if (userDoc.exists) {
            Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
            String? storedDeviceId = data['deviceId'];

            // 4. DEVICE LOCK LOGIC
            // Access granted if: Device matches, or device is currently unset (Admin reset)
            if (storedDeviceId == null || storedDeviceId == "" || storedDeviceId == currentDeviceId) {
              
              // Update/Lock the device ID for this user
              await FirebaseFirestore.instance.collection('users').doc(phoneDocId).set({
                'deviceId': currentDeviceId,
                'lastLogin': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (context) => DashboardScreen()), 
                  (route) => false, 
                );
              }
            } else {
              // BLOCK: Device ID mismatch
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                setState(() => _isVerifying = false);
                _showError("Handset Mismatch! This account is locked to another device. Contact Admin.");
              }
            }
          } else {
            // NEW USER: Proceed to registration
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (context) => const RegistrationScreen()), 
                (route) => false, 
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isVerifying = false);
          _showError("Authentication Failed: $e");
        }
      }
    } else {
      if (mounted) {
        setState(() => _isVerifying = false);
        _showError("Incorrect OTP code.");
      }
    }
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 100,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Row(
            children: [
              Icon(Icons.arrow_back_ios, size: 18, color: espresso),
              Text("Login", style: GoogleFonts.montserrat(color: espresso, fontWeight: FontWeight.bold)),
            ],
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            Text("Verify your OTP", style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.bold, color: espresso)),
            const SizedBox(height: 15),
            Text("Please enter the OTP you received on your mobile phone", 
                style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600], height: 1.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(widget.phoneNumber, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Edit number", style: GoogleFonts.montserrat(color: caramel, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) => _otpBox(index)),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Didn't receive the code?", style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600])),
                TextButton(
                  onPressed: _resendOTP,
                  child: Text("RESEND SMS", style: GoogleFonts.montserrat(color: caramel, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _isVerifying 
              ? Center(child: CircularProgressIndicator(color: espresso)) 
              : RegistrationShinyButton(text: "VERIFY OTP", onPressed: _verifyOTP),
          ],
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 45,
      height: 55,
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: caramel.withOpacity(0.5), width: 1.5),
      ),
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) => _onKeyEvent(event, index),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          autofocus: index == 0,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold, color: espresso),
          decoration: const InputDecoration(counterText: "", border: InputBorder.none),
          onChanged: (value) {
            if (value.length == 1 && index < 5) {
              _focusNodes[index + 1].requestFocus();
            }
          },
        ),
      ),
    );
  }
}