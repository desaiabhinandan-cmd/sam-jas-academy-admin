import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminCouponScreen extends StatefulWidget {
  const AdminCouponScreen({super.key});

  @override
  State<AdminCouponScreen> createState() => _AdminCouponScreenState();
}

class _AdminCouponScreenState extends State<AdminCouponScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime? _selectedDate;
  bool _isPercentage = false;
  final Color goldAccent = const Color(0xFFD4A373);

  void _presentDatePicker() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (pickedDate != null) {
      setState(() => _selectedDate = pickedDate);
    }
  }

  void _saveCoupon() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and select an expiry date")),
      );
      return;
    }

    String code = _codeController.text.trim().toUpperCase();

    try {
      // IDEAL DB STRUCTURE: Using 'discountValue' for consistency
      await FirebaseFirestore.instance.collection('coupons').doc(code).set({
        'discountValue': num.parse(_amountController.text), // Changed from discountAmount
        'isPercentage': _isPercentage,
        'expiryDate': Timestamp.fromDate(_selectedDate!),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green, content: Text("Coupon $code Created!")),
      );
      
      _codeController.clear();
      _amountController.clear();
      setState(() => _selectedDate = null);
    } catch (e) {
      debugPrint("Error creating coupon: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("COUPON MANAGER", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("CREATE NEW CODE", style: GoogleFonts.montserrat(color: goldAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildTextField(_codeController, "COUPON CODE (e.g. SAVE500)", Icons.local_offer),
              const SizedBox(height: 16),
              _buildTextField(_amountController, "DISCOUNT VALUE", Icons.currency_rupee, isNumber: true),
              SwitchListTile(
                title: const Text("Is this a percentage discount?", style: TextStyle(color: Colors.white70, fontSize: 14)),
                value: _isPercentage,
                activeColor: goldAccent,
                onChanged: (val) => setState(() => _isPercentage = val),
              ),
              const SizedBox(height: 16),
              ListTile(
                tileColor: Colors.white.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(Icons.calendar_today, color: goldAccent),
                title: Text(
                  _selectedDate == null ? "SELECT EXPIRY DATE" : "EXPIRES ON: ${DateFormat('dd MMM yyyy').format(_selectedDate!)}",
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                onTap: _presentDatePicker,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveCoupon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldAccent,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("SAVE COUPON", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
              Text("ACTIVE COUPONS", style: GoogleFonts.montserrat(color: goldAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('coupons').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      // Handle both old and new keys for the preview list
                      var val = data['discountValue'] ?? data['discountAmount'] ?? 0;
                      return Card(
                        color: Colors.white.withOpacity(0.05),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(doc.id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text("Value: $val${data['isPercentage'] ? '%' : ' OFF'}", style: const TextStyle(color: Colors.white38)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => doc.reference.delete(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        prefixIcon: Icon(icon, color: goldAccent, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (val) => val == null || val.isEmpty ? "Field Required" : null,
    );
  }
}