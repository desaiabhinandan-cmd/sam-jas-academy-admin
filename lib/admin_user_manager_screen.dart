import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'admin_accounts_screen.dart';
// Import your Accounts Screen here
// import 'admin_accounts_screen.dart'; 

class AdminUserManagerScreen extends StatefulWidget {
  const AdminUserManagerScreen({super.key});

  @override
  _AdminUserManagerScreenState createState() => _AdminUserManagerScreenState();
}

class _AdminUserManagerScreenState extends State<AdminUserManagerScreen> {
  final Color goldAccent = const Color(0xFFD4A373);
  final Color charcoalBg = const Color(0xFF121212);
  String _searchQuery = "";

  TextStyle montStyle({double size = 14, FontWeight weight = FontWeight.normal, Color color = Colors.white}) {
    return GoogleFonts.montserrat(fontSize: size, fontWeight: weight, color: color);
  }

  String _formatDateTime(dynamic data) {
    if (data == null) return "N/A";
    if (data is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(data.toDate());
    }
    return data.toString();
  }

  void _toggleAdmin(String userId, bool makeAdmin) {
    FirebaseFirestore.instance.collection('users').doc(userId).update({
      'role': makeAdmin ? 'admin' : 'user',
      'isAdmin': makeAdmin,
    });
  }

  void _resetDeviceLock(String userId, String name) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'deviceId': FieldValue.delete(),
      'lastDeviceReset': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Handset lock cleared for $name"), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: charcoalBg,
      appBar: AppBar(
        title: Text("USER MANAGER", style: montStyle(weight: FontWeight.bold)),
        backgroundColor: charcoalBg,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAccountsScreen()));
            },
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(65),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search name or phone...",
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: Icon(Icons.search, color: goldAccent),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var filteredDocs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>? ?? {};
            String name = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".toLowerCase();
            String phone = doc.id; 
            return name.contains(_searchQuery) || phone.contains(_searchQuery);
          }).toList();

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              var userDoc = filteredDocs[index];
              var data = userDoc.data() as Map<String, dynamic>;
              bool isAdmin = (data['role'] == 'admin' || data['isAdmin'] == true);
              
              // Case-insensitive check for the image URL key
              String? imgUrl = data['profileImageurl'] ?? data['profileImageUrl']; 

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAdmin ? goldAccent : Colors.white10,
                  // Using foregroundImage for a cleaner look
                  foregroundImage: (imgUrl != null && imgUrl.isNotEmpty) ? NetworkImage(imgUrl) : null,
                  child: Icon(
                    isAdmin ? Icons.security : Icons.person, 
                    color: isAdmin ? Colors.black : Colors.white60
                  ),
                ),
                title: Text("${data['firstName'] ?? 'User'} ${data['lastName'] ?? ''}", style: montStyle(weight: FontWeight.bold)),
                subtitle: Text(userDoc.id, style: montStyle(size: 12, color: Colors.white60)), 
                trailing: Switch(
                  value: isAdmin,
                  activeColor: goldAccent,
                  onChanged: (val) => _toggleAdmin(userDoc.id, val),
                ),
                onTap: () => _showUserDetails(userDoc, data),
              );
            },
          );
        },
      ),
    );
  }

  void _showUserDetails(DocumentSnapshot userDoc, Map<String, dynamic> data) {
    // Apply same fix here
    String? imgUrl = data['profileImageurl'] ?? data['profileImageUrl'];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: charcoalBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: goldAccent,
                foregroundImage: (imgUrl != null && imgUrl.toString().isNotEmpty) 
                    ? NetworkImage(imgUrl) 
                    : null,
                child: const Icon(Icons.person, size: 40, color: Colors.black),
              ),
              const SizedBox(height: 15),
              Text("USER RECORD", style: montStyle(size: 16, weight: FontWeight.bold, color: goldAccent)),
              const Divider(color: Colors.white10, height: 30),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _infoTile("PHONE (UID)", userDoc.id), 
                    ...data.entries
                        .where((e) => e.key != 'profileImageurl' && e.key != 'profileImageUrl')
                        .map((e) => _infoTile(e.key, _formatDateTime(e.value)))
                        .toList(),
                    
                    const SizedBox(height: 25),
                    Text("PAYMENT HISTORY", style: montStyle(size: 14, color: Colors.greenAccent, weight: FontWeight.bold)),
                    const Divider(color: Colors.greenAccent, thickness: 0.5),
                    
                    StreamBuilder<QuerySnapshot>(
                      stream: userDoc.reference.collection('payments').orderBy('timestamp', descending: true).snapshots(),
                      builder: (context, paySnap) {
                        if (!paySnap.hasData) return const LinearProgressIndicator();
                        if (paySnap.data!.docs.isEmpty) return Text("No transactions.", style: montStyle(color: Colors.white24));
                        
                        return Column(
                          children: paySnap.data!.docs.map((pDoc) {
                            var p = pDoc.data() as Map<String, dynamic>;
                            List items = p['items'] ?? [];
                            String courseName = items.isNotEmpty ? items[0]['title'] : "Unknown Course";
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(courseName, style: montStyle(size: 13, weight: FontWeight.bold, color: goldAccent))),
                                      Text("₹${p['amountPaid'] ?? '0'}", style: montStyle(size: 15, weight: FontWeight.bold, color: Colors.greenAccent)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _payDetailRow(Icons.receipt, "ID: ${p['paymentId'] ?? 'N/A'}"),
                                  _payDetailRow(Icons.calendar_today, _formatDateTime(p['timestamp'])),
                                  _payDetailRow(Icons.check_circle, "Status: ${p['status']}", 
                                      color: p['status'] == "Success" ? Colors.green : Colors.orange),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.1), 
                  side: const BorderSide(color: Colors.redAccent), 
                  minimumSize: const Size(double.infinity, 50)
                ),
                onPressed: () { Navigator.pop(context); _resetDeviceLock(userDoc.id, data['firstName'] ?? 'User'); },
                icon: const Icon(Icons.phonelink_erase, color: Colors.redAccent),
                label: Text("RESET DEVICE LOCK", style: montStyle(color: Colors.redAccent, weight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: goldAccent, minimumSize: const Size(double.infinity, 50)),
                onPressed: () => Navigator.pop(context),
                child: Text("CLOSE", style: montStyle(color: Colors.black, weight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _payDetailRow(IconData icon, String text, {Color color = Colors.white60}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: montStyle(size: 11, color: color))),
        ],
      ),
    );
  }

  Widget _infoTile(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(key.toUpperCase(), style: montStyle(size: 10, color: goldAccent, weight: FontWeight.bold))),
          Expanded(flex: 3, child: Text(value, style: montStyle(size: 12))),
        ],
      ),
    );
  }
}