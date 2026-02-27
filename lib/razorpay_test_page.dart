import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayTestPage extends StatefulWidget {
  const RazorpayTestPage({super.key});

  @override
  State<RazorpayTestPage> createState() => _RazorpayTestPageState();
}

class _RazorpayTestPageState extends State<RazorpayTestPage> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _showMsg("SUCCESS: ${response.paymentId}");
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showMsg("ERROR: ${response.code} - ${response.message}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showMsg("EXTERNAL WALLET: ${response.walletName}");
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openCheckout() {
    var options = {
      'key': 'rzp_test_SDyRscbJ7SgNC9', // Use your current dashboard key
      'amount': 409999, // ₹1.00
      'name': 'Test Academy',
      'description': 'Minimalist Test',
      'currency': 'INR',
      'prefill': {
        'contact': '9999999999',
        'email': 'test@example.com'
      },
      'timeout': 60, // 1 minute
    };
    
    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error opening checkout: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SAM AND JAS")),
      body: Center(
        child: ElevatedButton(
          onPressed: _openCheckout,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
          child: const Text("TEST PAYMENT GATEWAY"),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }
}