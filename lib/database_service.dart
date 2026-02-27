import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 1. GATEKEEPER LOGIC: Check if user needs to fill profile
  Future<bool> isProfileComplete() async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    DocumentSnapshot snap = await _db.collection('users').doc(user.uid).get();
    
    if (snap.exists) {
      Map<String, dynamic> data = snap.data() as Map<String, dynamic>;
      return data['profileCompleted'] ?? false;
    }
    return false;
  }

  // 2. PROFILE DATA SAVING (The 8 Fields + Image)
  Future<void> saveUserProfile({
    required String firstName,
    required String lastName,
    required String dob,
    required String email,
    required String gender,
    required String city,
    required String state,
    required String country,
    File? profileImage,
  }) async {
    String uid = _auth.currentUser!.uid;
    String? imageUrl;

    // Handle Image Upload to Firebase Storage first
    if (profileImage != null) {
      Reference ref = _storage.ref().child('profile_pics').child('$uid.jpg');
      UploadTask uploadTask = ref.putFile(profileImage);
      TaskSnapshot snapshot = await uploadTask;
      imageUrl = await snapshot.ref.getDownloadURL();
    }

    // Save all fields to Firestore
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'dob': dob,
      'email': email,
      'gender': gender,
      'city': city,
      'state': state,
      'country': country,
      'profilePic': imageUrl,
      'phoneNumber': _auth.currentUser!.phoneNumber,
      'profileCompleted': true, // The flag that lets them into the Dashboard
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}