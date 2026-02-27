import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// FIX 1: Hide Border from Excel to avoid conflict with Flutter's Border
import 'package:excel/excel.dart' hide Border; 
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  _AdminAccountsScreenState createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  final Color goldAccent = const Color(0xFFD4A373);
  final Color charcoalBg = const Color(0xFF121212);

  TextStyle montStyle({double size = 14, FontWeight weight = FontWeight.normal, Color color = Colors.white}) {
    return GoogleFonts.montserrat(fontSize: size, fontWeight: weight, color: color);
  }

  // --- UPDATED EXCEL LOGIC FOR VERSION 4.0+ ---
  Future<void> _downloadExcel() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Account Summary'];
      excel.delete('Sheet1');

      // FIX 2: Wrap headers in TextCellValue
      List<CellValue> header = [
        TextCellValue("Student Name"),
        TextCellValue("Email"),
        TextCellValue("Course Name"),
        TextCellValue("Date"),
        TextCellValue("Original Price"),
        TextCellValue("Coupon"),
        TextCellValue("Discount"),
        TextCellValue("Net Paid"),
        TextCellValue("Status")
      ];
      sheet.appendRow(header);

      var userSnap = await FirebaseFirestore.instance.collection('users').get();
      
      for (var userDoc in userSnap.docs) {
        var userData = userDoc.data();
        String fullName = "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}".trim();
        if (fullName.isEmpty) fullName = "New Student";

        var paymentSnap = await userDoc.reference.collection('payments').get();

        for (var payDoc in paymentSnap.docs) {
          var pData = payDoc.data();
          
          String courseName = "Course";
          if (pData['items'] != null && (pData['items'] as List).isNotEmpty) {
            courseName = pData['items'][0]['title'] ?? "Unnamed Course";
          }

          String dateStr = "N/A";
          if (pData['timestamp'] != null) {
            DateTime dt = (pData['timestamp'] as Timestamp).toDate();
            dateStr = "${dt.day}/${dt.month}/${dt.year}";
          }

          double paid = (pData['amountPaid'] ?? pData['amount'] ?? 0).toDouble();
          double disc = (pData['discount'] ?? 0).toDouble();

          // FIX 3: Wrap row data in specific CellValue types
          sheet.appendRow([
            TextCellValue(fullName),
            TextCellValue(userData['email'] ?? 'N/A'),
            TextCellValue(courseName),
            TextCellValue(dateStr),
            DoubleCellValue(paid + disc),
            TextCellValue(pData['couponUsed'] ?? 'None'),
            DoubleCellValue(disc),
            DoubleCellValue(paid),
            TextCellValue(pData['status'] ?? 'Success')
          ]);
        }
      }

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/Financial_Report.xlsx');
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(file.path)], text: 'Financial Accounts Export');
    } catch (e) {
      debugPrint("Excel Export Error: $e");
    }
  }

  Future<Map<String, dynamic>> _getDashboardStats() async {
    try {
      var userSnap = await FirebaseFirestore.instance.collection('users').count().get();
      var courseSnap = await FirebaseFirestore.instance.collection('courses').count().get();
      var paymentsSnap = await FirebaseFirestore.instance.collectionGroup('payments').get();

      double totalNetRevenue = 0;
      double totalGrossRevenue = 0;

      for (var doc in paymentsSnap.docs) {
        var data = doc.data();
        if (data['status'] == 'Success') {
          double netValue = (data['amountPaid'] ?? data['amount'] ?? 0).toDouble();
          double discountValue = (data['discount'] ?? 0).toDouble();

          totalNetRevenue += netValue;
          totalGrossRevenue += (netValue + discountValue);
        }
      }

      return {
        'totalUsers': userSnap.count ?? 0,
        'totalCourses': courseSnap.count ?? 0,
        'netRevenue': totalNetRevenue,
        'grossRevenue': totalGrossRevenue,
      };
    } catch (e) {
      debugPrint("Dashboard Error: $e");
      return {'totalUsers': 0, 'totalCourses': 0, 'netRevenue': 0.0, 'grossRevenue': 0.0};
    }
  }

  void _showPaymentHistory(BuildContext context, String userId, String userName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: charcoalBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("FINANCIAL AUDIT: $userName", style: montStyle(weight: FontWeight.bold, color: goldAccent)),
            const Divider(color: Colors.white10, height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('payments')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  if (snap.data!.docs.isEmpty) return Center(child: Text("No transactions found.", style: montStyle(color: Colors.white38)));

                  return ListView.builder(
                    itemCount: snap.data!.docs.length,
                    itemBuilder: (context, i) {
                      var pData = snap.data!.docs[i].data() as Map<String, dynamic>;
                      
                      String courseName = "Multiple Courses";
                      if (pData['items'] != null && (pData['items'] as List).isNotEmpty) {
                        var itemsList = pData['items'] as List;
                        courseName = itemsList.length == 1 
                          ? (itemsList[0]['title'] ?? "Unnamed Course") 
                          : "${itemsList.length} Courses (Bundle)";
                      }

                      double paid = (pData['amountPaid'] ?? pData['amount'] ?? 0).toDouble();
                      double disc = (pData['discount'] ?? 0).toDouble();
                      double original = paid + disc;
                      String coupon = pData['couponUsed'] ?? 'None';

                      String dateStr = "N/A";
                      if (pData['timestamp'] != null) {
                        DateTime dt = (pData['timestamp'] as Timestamp).toDate();
                        dateStr = "${dt.day}/${dt.month}/${dt.year}";
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(courseName, style: montStyle(size: 14, weight: FontWeight.bold))),
                                Text(pData['status'] ?? 'Success', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Original: ₹$original", style: montStyle(size: 11, color: Colors.white38)),
                                    Text("Coupon: $coupon (-₹$disc)", style: montStyle(size: 11, color: Colors.orangeAccent)),
                                    const SizedBox(height: 8),
                                    Text("Date: $dateStr", style: montStyle(size: 11, color: Colors.white38)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("NET PAID", style: montStyle(size: 9, color: goldAccent, weight: FontWeight.bold)),
                                    Text("₹${paid.toStringAsFixed(0)}", style: montStyle(size: 20, weight: FontWeight.bold)),
                                    Text("MODE: ONLINE", style: montStyle(size: 9, color: Colors.white24)),
                                  ],
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
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: charcoalBg,
      appBar: AppBar(
        title: Text("ADMIN DASHBOARD", style: montStyle(weight: FontWeight.bold)),
        backgroundColor: charcoalBg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.greenAccent),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating Excel Report...")));
              _downloadExcel();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _getDashboardStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              var stats = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
                child: Row(
                  children: [
                    _buildStatBox("NET", "₹${stats['netRevenue'].toStringAsFixed(0)}", Colors.greenAccent),
                    const SizedBox(width: 8),
                    _buildStatBox("GROSS", "₹${stats['grossRevenue'].toStringAsFixed(0)}", Colors.white54),
                    const SizedBox(width: 8),
                    _buildStatBox("USERS", "${stats['totalUsers']}", Colors.blueAccent),
                    const SizedBox(width: 8),
                    _buildStatBox("COURSES", "${stats['totalCourses']}", goldAccent),
                  ],
                ),
              );
            },
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String fName = data['firstName'] ?? '';
                    String lName = data['lastName'] ?? '';
                    String fullName = (fName + " " + lName).trim();
                    if (fullName.isEmpty) fullName = "New Student";

                    return ListTile(
                      onTap: () => _showPaymentHistory(context, doc.id, fullName),
                      leading: CircleAvatar(
                        backgroundColor: goldAccent.withOpacity(0.1),
                        child: Text(fullName.isNotEmpty ? fullName[0] : "?", style: TextStyle(color: goldAccent)),
                      ),
                      title: Text(fullName, style: montStyle(weight: FontWeight.bold)),
                      subtitle: Text(data['email'] ?? 'No email', style: montStyle(size: 11, color: Colors.white54)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(title, style: montStyle(size: 8, color: color, weight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(value, style: montStyle(size: 11, weight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}