import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MyPaymentsScreen extends StatelessWidget {
  const MyPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text("TRANSACTION HISTORY", 
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('payments')
            .orderBy('timestamp', descending: true) // Newest first
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD4A373)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text("No payments found.", 
                style: GoogleFonts.montserrat(color: Colors.white38)),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              
              // Formatting Dates
              DateTime date = (data['timestamp'] as Timestamp).toDate();
              DateTime expiry = (data['validUntil'] as Timestamp).toDate();
              String formattedDate = DateFormat('dd MMM yyyy').format(date);
              String formattedExpiry = DateFormat('dd MMM yyyy').format(expiry);

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const Text("PAID SUCCESS", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text("Payment ID: ${data['paymentId']}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const Divider(color: Colors.white10, height: 25),
                    
                    // List of items bought in this transaction
                    ...(data['items'] as List).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(item['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
                          Text("₹${item['price']}", style: const TextStyle(color: Color(0xFFD4A373))),
                        ],
                      ),
                    )).toList(),

                    const Divider(color: Colors.white10, height: 25),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("VALID UNTIL", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                            Text(formattedExpiry, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        // FIXED: Added fallback for 'amountPaid' to prevent null display
                        Text(
                          "₹${data['amount'] ?? data['amountPaid'] ?? '0'}", 
                          style: GoogleFonts.montserrat(
                            color: const Color(0xFFD4A373), 
                            fontSize: 22, 
                            fontWeight: FontWeight.w900
                          )
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}