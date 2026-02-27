import 'package:cloud_firestore/cloud_firestore.dart';

class AccessController {
  /// Checks if a course is still valid based on the subscription data map
  static bool isSubscriptionValid(Map<String, dynamic>? subscriptionData) {
    // 1. If no subscription data exists at all, access is denied
    if (subscriptionData == null) return false;

    // 2. Extract fields from your Firestore structure
    bool isActive = subscriptionData['isActive'] ?? false;
    Timestamp? expiryTimestamp = subscriptionData['expiryDate'];

    // 3. Logic: If it's manually disabled by Admin, deny access immediately
    if (!isActive) return false;

    // 4. Time Check
    if (expiryTimestamp != null) {
      DateTime expiryDate = expiryTimestamp.toDate();
      DateTime now = DateTime.now();

      // Returns true if today is BEFORE the expiry date
      return now.isBefore(expiryDate);
    }

    return false;
  }

  /// Optional: Returns the number of days remaining as a String
  static String getRemainingDays(Timestamp? expiryTimestamp) {
    if (expiryTimestamp == null) return "Expired";
    
    DateTime expiryDate = expiryTimestamp.toDate();
    int days = expiryDate.difference(DateTime.now()).inDays;
    
    return days > 0 ? "$days days left" : "Expires today";
  }
}