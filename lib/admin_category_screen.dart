import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCategoryScreen extends StatefulWidget {
  const AdminCategoryScreen({super.key});

  @override
  _AdminCategoryScreenState createState() => _AdminCategoryScreenState();
}

class _AdminCategoryScreenState extends State<AdminCategoryScreen> {
  final Color goldAccent = const Color(0xFFD4A373);
  final Color charcoalBg = const Color(0xFF121212);
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();

  TextStyle montStyle({double size = 14, FontWeight weight = FontWeight.normal, Color color = Colors.white}) {
    return GoogleFonts.montserrat(fontSize: size, fontWeight: weight, color: color);
  }

  // Unified Save function for both Add and Edit
  Future<void> _saveCategory({String? docId}) async {
    if (_nameController.text.isEmpty || _imageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'imageUrl': _imageController.text.trim(),
      'order': int.tryParse(_orderController.text) ?? 0,
    };

    if (docId == null) {
      await FirebaseFirestore.instance.collection('categories').add(data);
    } else {
      await FirebaseFirestore.instance.collection('categories').doc(docId).update(data);
    }

    _nameController.clear();
    _imageController.clear();
    _orderController.clear();
    
    if(mounted) Navigator.pop(context);
  }

  void _showCategorySheet({String? docId, String? currentName, String? currentUrl, int? currentOrder}) {
    // If editing, pre-fill the controllers
    if (docId != null) {
      _nameController.text = currentName ?? "";
      _imageController.text = currentUrl ?? "";
      _orderController.text = currentOrder?.toString() ?? "0";
    } else {
      _nameController.clear();
      _imageController.clear();
      _orderController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: charcoalBg,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(docId == null ? "ADD CATEGORY" : "EDIT CATEGORY", 
              style: montStyle(size: 18, weight: FontWeight.bold, color: goldAccent)),
            const SizedBox(height: 15),
            _buildTextField(_nameController, "Category Name"),
            _buildTextField(_imageController, "Image URL"),
            _buildTextField(_orderController, "Display Order", isNumber: true),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: goldAccent, minimumSize: const Size(double.infinity, 50)),
              onPressed: () => _saveCategory(docId: docId),
              child: Text("CONFIRM CHANGES", style: montStyle(color: Colors.black, weight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: goldAccent.withOpacity(0.3))),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: goldAccent)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: charcoalBg,
      appBar: AppBar(
        title: Text("CATEGORY MANAGER", style: montStyle(weight: FontWeight.bold)),
        backgroundColor: charcoalBg,
        iconTheme: IconThemeData(color: goldAccent),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: goldAccent,
        onPressed: () => _showCategorySheet(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('categories').orderBy('order').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              
              return ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(data['imageUrl'] ?? '')),
                title: Text(data['name'] ?? '', style: montStyle(weight: FontWeight.bold)),
                subtitle: Text("Order: ${data['order']}", style: montStyle(size: 12, color: Colors.white60)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.blueAccent),
                      onPressed: () => _showCategorySheet(
                        docId: doc.id,
                        currentName: data['name'],
                        currentUrl: data['imageUrl'],
                        currentOrder: data['order'],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(doc.id),
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

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: charcoalBg,
        title: Text("Delete Category?", style: montStyle(weight: FontWeight.bold)),
        content: Text("This will not delete the courses inside it, but they may become hidden.", style: montStyle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('categories').doc(id).delete();
              Navigator.pop(context);
            }, 
            child: const Text("DELETE", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }
}