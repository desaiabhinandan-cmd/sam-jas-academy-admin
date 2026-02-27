import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; // Added for Windows Server Upload
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'shiny_button.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final bool isFromDashboard;

  const RegistrationScreen({super.key, this.isFromDashboard = false});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  File? _imageFile;
  String? _existingImageUrl; 
  final _picker = ImagePicker();
  bool _isSaving = false;

  // --- THEME PALETTE ---
  final Color darkCanvas = const Color(0xFF0F0F0F);
  final Color goldAccent = const Color(0xFFD4A373);
  final Color cardGrey = const Color(0xFF1A1A1A);
  final Color espresso = const Color(0xFF4A342B);
  final Color cream = const Color(0xFFFFFDF1);

  Color get bgColor => widget.isFromDashboard ? darkCanvas : cream;
  Color get primaryText => widget.isFromDashboard ? Colors.white : espresso;
  Color get secondaryText => widget.isFromDashboard ? Colors.white70 : espresso.withOpacity(0.7);
  Color get accentColor => widget.isFromDashboard ? goldAccent : espresso;
  Color get fieldColor => widget.isFromDashboard ? cardGrey : Colors.white;

  final _fNameController = TextEditingController();
  final _lNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: "India");
  final _certNameController = TextEditingController();
  String _selectedGender = 'Male';

  @override
  void initState() {
    super.initState();
    _loadExistingUserData();
    _warmUpServer(); // Wake up the server immediately when screen opens
  }

  // --- LOGIC: WAKE UP COLD SERVER ---
  Future<void> _warmUpServer() async {
    try {
      await http.get(Uri.parse("http://samandjas.com/api/test_uploads/"))
          .timeout(const Duration(seconds: 2));
      debugPrint("DEBUG: Server engine warmed up.");
    } catch (_) {}
  }

  Future<void> _loadExistingUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String uid = user.uid;
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      var data = doc.data() as Map<String, dynamic>;
      setState(() {
        _fNameController.text = data['firstName'] ?? '';
        _lNameController.text = data['lastName'] ?? '';
        _dobController.text = data['dob'] ?? '';
        _emailController.text = data['email'] ?? '';
        _cityController.text = data['city'] ?? '';
        _stateController.text = data['state'] ?? '';
        _countryController.text = data['country'] ?? 'India';
        _certNameController.text = data['nameOnCertificate'] ?? '';
        _selectedGender = data['gender'] ?? 'Male';
        _existingImageUrl = data['profileImageUrl']; 
      });
    }
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: goldAccent, size: 20),
      hintText: label,
      hintStyle: GoogleFonts.montserrat(color: secondaryText.withOpacity(0.5)),
      filled: true,
      fillColor: fieldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: goldAccent.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: goldAccent),
      ),
      errorStyle: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 11),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leadingWidth: 100,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: TextButton.icon(
          onPressed: () {
            if (widget.isFromDashboard) {
              Navigator.pop(context);
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            }
          },
          icon: Icon(Icons.arrow_back_ios, size: 16, color: goldAccent),
          label: Text("Back", style: GoogleFonts.montserrat(color: goldAccent, fontWeight: FontWeight.bold)),
        ),
        title: Text(
          widget.isFromDashboard ? "EDIT PROFILE" : "FILL YOUR PROFILE",
          style: GoogleFonts.montserrat(
            color: primaryText, 
            fontWeight: FontWeight.w800, 
            letterSpacing: widget.isFromDashboard ? 1.5 : 0
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                children: [
                  () {
                    if (_imageFile != null) {
                      return CircleAvatar(
                        radius: 55,
                        backgroundColor: goldAccent.withOpacity(0.1),
                        backgroundImage: FileImage(_imageFile!),
                      );
                    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
                      return CircleAvatar(
                        radius: 55,
                        backgroundColor: goldAccent.withOpacity(0.1),
                        backgroundImage: NetworkImage(_existingImageUrl!),
                      );
                    } else {
                      return CircleAvatar(
                        radius: 55,
                        backgroundColor: goldAccent.withOpacity(0.1),
                        child: Icon(Icons.person, size: 55, color: goldAccent.withOpacity(0.5)),
                      );
                    }
                  }(),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: goldAccent, shape: BoxShape.circle),
                        child: Icon(Icons.camera_alt, color: widget.isFromDashboard ? Colors.black : Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              _buildField(_fNameController, "* First Name", Icons.person_outline, required: true),
              _buildField(_lNameController, "* Last Name", Icons.person_outline, required: true),
              
              if (widget.isFromDashboard)
                _buildField(_certNameController, "Name on Certificate", Icons.workspace_premium),

              _buildDateField(),
              _buildField(_emailController, "* Email", Icons.email_outlined, required: true, isEmail: true),

              DropdownButtonFormField<String>(
                value: _selectedGender,
                dropdownColor: fieldColor,
                style: GoogleFonts.montserrat(color: primaryText),
                items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setState(() => _selectedGender = val!),
                decoration: _inputStyle("Gender", Icons.people_outline),
              ),
              const SizedBox(height: 15),

              _buildField(_cityController, "* City", Icons.location_city, required: true),
              _buildField(_stateController, "* State", Icons.map_outlined, required: true),
              _buildCountryField(),

              const SizedBox(height: 40),

              _isSaving
                  ? CircularProgressIndicator(color: goldAccent)
                  : RegistrationShinyButton(
                      text: widget.isFromDashboard ? "SAVE CHANGES" : "CONTINUE",
                      onPressed: _saveProfile,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool required = false, bool isEmail = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.montserrat(color: primaryText),
        decoration: _inputStyle(label, icon),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) return 'Required Field';
          if (isEmail && v != null && v.isNotEmpty && !v.contains('@')) return 'Invalid Email Address';
          return null;
        },
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: _dobController,
        readOnly: true,
        style: GoogleFonts.montserrat(color: primaryText),
        decoration: _inputStyle("* Date of Birth", Icons.calendar_today_outlined),
        onTap: _selectDate,
        validator: (v) => (v == null || v.isEmpty) ? 'Required Field' : null,
      ),
    );
  }

  Widget _buildCountryField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: _countryController,
        readOnly: true,
        style: GoogleFonts.montserrat(color: primaryText),
        decoration: _inputStyle("* Country", Icons.public),
        onTap: _selectCountry,
        validator: (v) => (v == null || v.isEmpty) ? 'Required Field' : null,
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(primary: goldAccent, onPrimary: Colors.black, surface: cardGrey, onSurface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dobController.text = DateFormat('dd/MM/yyyy').format(picked));
  }

  void _selectCountry() {
    showCountryPicker(
      context: context,
      onSelect: (c) => setState(() => _countryController.text = c.name),
      countryListTheme: CountryListThemeData(
        backgroundColor: fieldColor,
        textStyle: GoogleFonts.montserrat(color: primaryText),
      ),
    );
  }

  Future<String?> _getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) return (await deviceInfo.androidInfo).id;
    if (Platform.isIOS) return (await deviceInfo.iosInfo).identifierForVendor;
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _isSaving = true);
    
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Auth session not found.");

      String uid = user.uid;
      String? deviceId = await _getDeviceId();
      String fName = _fNameController.text.trim();
      String lName = _lNameController.text.trim();
      String fullName = "$fName $lName";
      String? updatedImageUrl;

      if (_imageFile != null) {
        debugPrint("DEBUG: Uploading profile image to Windows Server...");
        
        // --- AUTO-PULSE LOGIC FOR COLD START ---
        Future<http.StreamedResponse> sendPulse() async {
          var request = http.MultipartRequest(
            'POST', 
            Uri.parse("http://samandjas.com/api/upload?uid=$uid")
          );
          request.files.add(await http.MultipartFile.fromPath('file', _imageFile!.path));
          return await request.send().timeout(const Duration(seconds: 30));
        }

        // Pulse 1
        var streamedResponse = await sendPulse();

        // Pulse 2: Automatic retry if server rejected with 403 or 401
        if (streamedResponse.statusCode == 403 || streamedResponse.statusCode == 401) {
          debugPrint("DEBUG: Pulse 1 rejected (${streamedResponse.statusCode}). Retrying Pulse 2...");
          await Future.delayed(const Duration(seconds: 1));
          streamedResponse = await sendPulse();
        }

        if (streamedResponse.statusCode == 200) {
          String version = DateTime.now().millisecondsSinceEpoch.toString();
          updatedImageUrl = "http://samandjas.com/api/test_uploads/$uid.jpg?v=$version";
        } else {
          throw Exception("Server Error (Status: ${streamedResponse.statusCode})");
        }
      } else {
        String defaultAvatar = "https://ui-avatars.com/api/?name=${fName}+${lName}&background=D4A373&color=fff";
        updatedImageUrl = (_existingImageUrl != null && !_existingImageUrl!.contains("ui-avatars.com"))
            ? _existingImageUrl
            : defaultAvatar;
      }

      Map<String, dynamic> userData = {
        'uid': uid,
        'firstName': fName,
        'lastName': lName,
        'dob': _dobController.text,
        'email': _emailController.text.trim(),
        'gender': _selectedGender,
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'country': _countryController.text.trim(),
        'profileImageUrl': updatedImageUrl, 
        'phoneNumber': user.phoneNumber ?? "Not Available",
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String certInput = _certNameController.text.trim();
      userData['nameOnCertificate'] = certInput.isNotEmpty ? certInput : fullName;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!userDoc.exists || (userDoc.data() as Map?)?['registeredDeviceId'] == null) {
        userData['registeredDeviceId'] = deviceId;
        userData['createdAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set(userData, SetOptions(merge: true));
      
      if (mounted) {
        setState(() {
          _imageFile = null;
          _existingImageUrl = updatedImageUrl;
          _isSaving = false;
        });

        if (widget.isFromDashboard) {
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (context) => DashboardScreen()), 
            (route) => false
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      debugPrint("DEBUG: Error in _saveProfile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Profile Error: ${e.toString()}"), backgroundColor: Colors.redAccent)
      );
    }
  }
}