import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:sam_jas_academy/my_courses_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Color goldAccent = const Color(0xFFD4A373);
  final Color darkCard = const Color(0xFF1A1A1A);
  late Razorpay _razorpay;
  bool isProcessing = false;

  final TextEditingController _couponController = TextEditingController();
  double discountAmount = 0.0;
  String? appliedCouponCode;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _showCouponList(num subtotal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("AVAILABLE OFFERS", style: GoogleFonts.montserrat(color: goldAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Divider(color: Colors.white10, height: 30),
              Flexible(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('coupons').where('isActive', isEqualTo: true).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    var docs = snapshot.data!.docs.where((doc) {
                      DateTime expiry = (doc['expiryDate'] as Timestamp).toDate();
                      return DateTime.now().isBefore(expiry);
                    }).toList();

                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("No coupons available right now.", style: TextStyle(color: Colors.white24)),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        String code = docs[index].id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: darkCard, borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(data['description'] ?? "Special Discount", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            trailing: TextButton(
                              onPressed: () {
                                _couponController.text = code;
                                _applyCoupon(subtotal);
                                Navigator.pop(context);
                              },
                              child: Text("APPLY", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applyCoupon(num currentSubtotal) async {
    String code = _couponController.text.trim().toUpperCase();
    setState(() { discountAmount = 0.0; appliedCouponCode = null; });
    if (code.isEmpty) return;

    try {
      var doc = await FirebaseFirestore.instance.collection('coupons').doc(code).get();
      if (doc.exists) {
        var data = doc.data()!;
        DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
        if (data['isActive'] == true && DateTime.now().isBefore(expiry)) {
          double val = (data['discountValue'] ?? data['discountAmount'] ?? 0).toDouble();
          bool isPercent = data['isPercentage'] ?? false;
          setState(() {
            appliedCouponCode = code;
            discountAmount = isPercent ? (currentSubtotal * val) / 100 : val;
          });
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Coupon Applied Successfully!")));
        } else { _showError("This coupon has expired or is inactive."); }
      } else { _showError("Invalid coupon code."); }
    } catch (e) { _showError("Error validating coupon."); }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(msg)));
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => isProcessing = true);
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final cartSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).collection('cart').get();
      if (cartSnapshot.docs.isEmpty) return;
      final DateTime now = DateTime.now();
      final DateTime expiryDate = now.add(const Duration(days: 365));
      final List<String> courseIds = cartSnapshot.docs.map((doc) => doc.id).toList();
      final List<Map<String, dynamic>> itemsList = cartSnapshot.docs.map((doc) => {
            'courseId': doc.id,
            'title': doc['title'] ?? 'Course',
            'price': doc['price'] ?? 0,
          }).toList();
      num subtotal = itemsList.fold(0, (sum, item) => sum + item['price']);
      num finalTotal = subtotal - discountAmount;
      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
        'enrolledCourses': FieldValue.arrayUnion(courseIds),
        'hasActiveCart': false,
        'lastActivity': FieldValue.serverTimestamp(),
      });
      Map<String, dynamic> subscriptionUpdates = {};
      for (var id in courseIds) {
        subscriptionUpdates['subscriptions.$id'] = {
          'purchaseDate': Timestamp.fromDate(now),
          'expiryDate': Timestamp.fromDate(expiryDate),
          'isActive': true,
        };
      }
      batch.update(FirebaseFirestore.instance.collection('users').doc(uid), subscriptionUpdates);
      DocumentReference paymentRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('payments').doc();
      batch.set(paymentRef, {
        'paymentId': response.paymentId,
        'orderId': response.orderId ?? 'N/A',
        'subtotal': subtotal,
        'discount': discountAmount,
        'couponUsed': appliedCouponCode,
        'amountPaid': finalTotal,
        'items': itemsList,
        'validUntil': Timestamp.fromDate(expiryDate),
        'status': 'Success',
        'timestamp': FieldValue.serverTimestamp(),
      });
      for (var doc in cartSnapshot.docs) { batch.delete(doc.reference); }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Purchase Successful!")));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyCoursesScreen()));
      }
    } catch (e) { debugPrint("Checkout DB Error: $e"); }
    finally { if (mounted) setState(() => isProcessing = false); }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => isProcessing = false);
    _showError(response.code == Razorpay.PAYMENT_CANCELLED ? "Payment cancelled." : "Payment Failed: ${response.message}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _checkout(num finalAmount) {
    if (finalAmount <= 0) return;
    int amountInPaise = (finalAmount * 100).toInt();
    var options = {
      'key': 'rzp_test_SF9n75zTJm8ZN9',
      'amount': amountInPaise,
      'currency': 'INR',
      'name': 'Sam & Jas Academy',
      'description': 'Course Enrollment',
      'prefill': {'contact': '9876543210', 'email': FirebaseAuth.instance.currentUser?.email ?? 'test@example.com'},
    };
    try { _razorpay.open(options); } catch (e) { setState(() => isProcessing = false); }
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text("MY CART", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('cart').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("Your bag is empty", style: GoogleFonts.montserrat(color: Colors.white24, fontWeight: FontWeight.bold)));
          }
          final cartItems = snapshot.data!.docs;
          num subtotal = cartItems.fold(0, (sum, doc) => sum + (doc['price'] ?? 0));
          num finalTotal = (subtotal - discountAmount).clamp(0, double.infinity);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: darkCard, borderRadius: BorderRadius.circular(15)),
                      child: Row(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(item['thumbnailUrl'] ?? '', width: 85, height: 85, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.white10, width: 85, height: 85))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['title'] ?? 'Course', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                
                                // FIX: Count videos from 'lessons' sub-collection and fetch Duration
                                FutureBuilder<List<dynamic>>(
                                  future: Future.wait([
                                    FirebaseFirestore.instance.collection('courses').doc(item.id).get(),
                                    FirebaseFirestore.instance.collection('courses').doc(item.id).collection('lessons').count().get(),
                                  ]),
                                  builder: (context, AsyncSnapshot<List<dynamic>> asyncSnapshot) {
                                    if (!asyncSnapshot.hasData) return const SizedBox(height: 14);
                                    
                                    var courseSnap = asyncSnapshot.data![0] as DocumentSnapshot;
                                    var countSnap = asyncSnapshot.data![1] as AggregateQuerySnapshot;
                                    var courseData = courseSnap.data() as Map<String, dynamic>?;

                                    String duration = courseData?['duration']?.toString() ?? 
                                                      courseData?['totalHours']?.toString() ?? "0 Hours";
                                    
                                    int videoCount = countSnap.count ?? 0;

                                    return Row(
                                      children: [
                                        const Icon(Icons.play_circle_outline, size: 12, color: Colors.white38),
                                        const SizedBox(width: 4),
                                        Text("$videoCount Videos", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.access_time, size: 12, color: Colors.white38),
                                        const SizedBox(width: 4),
                                        Text(duration, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: goldAccent.withOpacity(0.1), 
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: goldAccent.withOpacity(0.2), width: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calendar_today, size: 10, color: goldAccent),
                                      const SizedBox(width: 5),
                                      Text("VALIDITY: 1 YEAR ACCESS", 
                                        style: GoogleFonts.montserrat(color: goldAccent, fontSize: 8, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text("₹${item['price']}", style: GoogleFonts.montserrat(color: goldAccent, fontWeight: FontWeight.w900, fontSize: 16)),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close, color: Colors.white24, size: 20), onPressed: () => item.reference.delete()),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("COUPONS", style: GoogleFonts.montserrat(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () => _showCouponList(subtotal),
                      child: Text("VIEW ALL OFFERS", style: GoogleFonts.montserrat(color: goldAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: TextField(
                  controller: _couponController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "ENTER CODE",
                    hintStyle: GoogleFonts.montserrat(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: darkCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: TextButton(onPressed: () => _applyCoupon(subtotal), child: Text("APPLY", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: Colors.black, borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), border: Border(top: BorderSide(color: goldAccent.withOpacity(0.2)))),
                child: SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _summaryRow("Subtotal", "₹$subtotal"),
                    if (appliedCouponCode != null) Padding(padding: const EdgeInsets.only(top: 10), child: _summaryRow("Discount ($appliedCouponCode)", "-₹${discountAmount.toStringAsFixed(0)}", isDiscount: true)),
                    const Divider(color: Colors.white10, height: 30),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text("TOTAL AMOUNT", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                      Text("₹${finalTotal.toStringAsFixed(0)}", style: GoogleFonts.montserrat(color: goldAccent, fontSize: 24, fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isProcessing ? null : () => _checkout(finalTotal),
                      style: ElevatedButton.styleFrom(backgroundColor: goldAccent, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      child: isProcessing ? const CircularProgressIndicator(color: Colors.black) : Text("PROCEED TO CHECKOUT", style: GoogleFonts.montserrat(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ]),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _summaryRow(String title, String value, {bool isDiscount = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: TextStyle(color: isDiscount ? Colors.green : Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
      Text(value, style: TextStyle(color: isDiscount ? Colors.green : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
    ]);
  }

  @override
  void dispose() { _razorpay.clear(); _couponController.dispose(); super.dispose(); }
}