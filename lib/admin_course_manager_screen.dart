import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_lesson_manager_screen.dart'; // Ensure this file exists
import 'dart:io'; 
import 'package:excel/excel.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:share_plus/share_plus.dart'; 

class AdminCourseManagerScreen extends StatefulWidget {
  const AdminCourseManagerScreen({super.key});

  @override
  _AdminCourseManagerScreenState createState() => _AdminCourseManagerScreenState();
}

class _AdminCourseManagerScreenState extends State<AdminCourseManagerScreen> {
  final Color goldAccent = const Color(0xFFD4A373);
  final Color charcoalBg = const Color(0xFF121212);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _promoUrlController = TextEditingController();
  final TextEditingController _pdfUrlController = TextEditingController();
  final TextEditingController _certUrlController = TextEditingController();
  
  String? _selectedCategory;

  TextStyle montStyle({double size = 14, FontWeight weight = FontWeight.normal, Color color = Colors.white}) {
    return GoogleFonts.montserrat(fontSize: size, fontWeight: weight, color: color);
  }

  // --- UPDATED: SMART EXCEL GENERATOR (With videoUrl and order) ---
  Future<void> _downloadSmartLessonTemplate(String courseId, String courseTitle) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    // 1. Define Headers exactly as per your Firestore structure
    List<CellValue> headers = [
      TextCellValue("DocID (Do Not Edit)"), 
      TextCellValue("order"),
      TextCellValue("title"),
      TextCellValue("videoUrl"),
      TextCellValue("duration"),
      TextCellValue("description")
    ];
    sheetObject.appendRow(headers);

    // 2. Fetch existing lessons from Firestore
    var lessonSnapshot = await FirebaseFirestore.instance
        .collection('courses')
        .doc(courseId)
        .collection('lessons')
        .orderBy('order') // Keeps the curriculum sequence
        .get();

    if (lessonSnapshot.docs.isNotEmpty) {
      // 3. Fill Excel with existing data for editing/syncing
      for (var doc in lessonSnapshot.docs) {
        var data = doc.data();
        
        // Ensure 'order' is handled as an integer
        int orderVal = 0;
        if (data['order'] is int) {
          orderVal = data['order'];
        } else if (data['order'] != null) {
          orderVal = int.tryParse(data['order'].toString()) ?? 0;
        }

        sheetObject.appendRow([
          TextCellValue(doc.id), 
          IntCellValue(orderVal),
          TextCellValue(data['title']?.toString() ?? ''),
          TextCellValue(data['videoUrl']?.toString() ?? ''),
          TextCellValue(data['duration']?.toString() ?? ''),
          TextCellValue(data['description']?.toString() ?? ''),
        ]);
      }
    } else {
      // 4. Add Sample Row if course is empty
      sheetObject.appendRow([
        TextCellValue(""), // Empty ID = Create New on upload
        IntCellValue(1),
        TextCellValue("Lesson 1: Introduction"),
        TextCellValue("https://example.com/video1.mp4"),
        TextCellValue("10:00"),
        TextCellValue("Basic introduction to the topic."),
      ]);
    }

    var fileBytes = excel.save();
    final directory = await getTemporaryDirectory();
    String safeTitle = courseTitle.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final file = File('${directory.path}/${safeTitle}_Curriculum.xlsx');
    
    await file.writeAsBytes(fileBytes!);

    await Share.shareXFiles(
      [XFile(file.path)], 
      text: 'Lesson curriculum for $courseTitle. Open in Excel to add/edit.'
    );
  }

  Future<void> _saveCourse({String? docId}) async {
    if (_titleController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title and Category are required")));
      return;
    }

    final Map<String, dynamic> courseData = {
      'title': _titleController.text.trim(),
      'category': _selectedCategory,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'thumbnailUrl': _imageController.text.trim(),
      'description': _descController.text.trim(),
      'duration': _durationController.text.trim(),
      'promoVideoUrl': _promoUrlController.text.trim(),
      'theoryPdfUrl': _pdfUrlController.text.trim(),
      'certificateTemplateUrl': _certUrlController.text.trim(),
    };

    if (docId == null) {
      await FirebaseFirestore.instance.collection('courses').add(courseData);
    } else {
      await FirebaseFirestore.instance.collection('courses').doc(docId).update(courseData);
    }

    if (mounted) Navigator.pop(context);
    _clearInputs();
  }

  void _clearInputs() {
    _titleController.clear();
    _priceController.clear();
    _imageController.clear();
    _descController.clear();
    _durationController.clear();
    _promoUrlController.clear();
    _pdfUrlController.clear();
    _certUrlController.clear();
    _selectedCategory = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: charcoalBg,
      appBar: AppBar(
        title: Text("COURSE MANAGER", style: montStyle(weight: FontWeight.bold)),
        backgroundColor: charcoalBg,
        iconTheme: IconThemeData(color: goldAccent),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: goldAccent,
        onPressed: () => _showCourseSheet(),
        child: const Icon(Icons.add_to_photos, color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('courses').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String thumb = data['thumbnailUrl'] ?? '';
              String title = data['title'] ?? 'No Title';
              
              return ListTile(
                leading: thumb.isNotEmpty 
                  ? Image.network(thumb, width: 50, errorBuilder: (c, e, s) => const Icon(Icons.book, color: Colors.white24))
                  : const Icon(Icons.image_not_supported, color: Colors.white24),
                title: Text(title, style: montStyle(weight: FontWeight.bold)),
                subtitle: Text("${data['category']} - ₹${data['price']}", style: montStyle(size: 12, color: goldAccent)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: "Download/Sync Curriculum",
                      icon: const Icon(Icons.download_for_offline, color: Colors.orangeAccent),
                      onPressed: () => _downloadSmartLessonTemplate(doc.id, title),
                    ),
                    IconButton(
                      icon: const Icon(Icons.video_collection_outlined, color: Colors.greenAccent),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminLessonManagerScreen(
                            courseId: doc.id, 
                            courseTitle: title,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _showCourseSheet(docId: doc.id, data: data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                      onPressed: () => FirebaseFirestore.instance.collection('courses').doc(doc.id).delete(),
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

  void _showCourseSheet({String? docId, Map<String, dynamic>? data}) {
    if (docId != null && data != null) {
      _titleController.text = data['title'] ?? '';
      _priceController.text = data['price']?.toString() ?? '';
      _imageController.text = data['thumbnailUrl'] ?? '';
      _descController.text = data['description'] ?? '';
      _durationController.text = data['duration'] ?? '';
      _promoUrlController.text = data['promoVideoUrl'] ?? '';
      _pdfUrlController.text = data['theoryPdfUrl'] ?? '';
      _certUrlController.text = data['certificateTemplateUrl'] ?? '';
      _selectedCategory = data['category'];
    } else {
      _clearInputs();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: charcoalBg,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(docId == null ? "CREATE COURSE" : "EDIT COURSE", style: montStyle(size: 18, weight: FontWeight.bold, color: goldAccent)),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('categories').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const LinearProgressIndicator();
                    List<String> categories = snap.data!.docs.map((d) => d['name'].toString()).toList();
                    if (_selectedCategory != null && !categories.contains(_selectedCategory)) {
                      _selectedCategory = null; 
                    }

                    return DropdownButtonFormField<String>(
                      dropdownColor: charcoalBg,
                      value: _selectedCategory,
                      decoration: _inputDecoration("Select Category"),
                      items: categories.map((name) => DropdownMenuItem(
                        value: name, 
                        child: Text(name, style: const TextStyle(color: Colors.white))
                      )).toList(),
                      onChanged: (val) => setSheetState(() => _selectedCategory = val),
                    );
                  },
                ),
                _buildField(_titleController, "Course Title"),
                _buildField(_priceController, "Price", isNum: true),
                _buildField(_durationController, "Duration (e.g. 5 Hours)"),
                _buildField(_imageController, "Thumbnail URL"),
                _buildField(_promoUrlController, "Promo Video URL (YouTube ID)"),
                _buildField(_pdfUrlController, "Theory PDF URL"),
                _buildField(_certUrlController, "Certificate Template URL"),
                _buildField(_descController, "Description", lines: 3),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: goldAccent, minimumSize: const Size(double.infinity, 50)),
                  onPressed: () => _saveCourse(docId: docId),
                  child: Text("SAVE COURSE", style: montStyle(color: Colors.black, weight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: Colors.white60),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: goldAccent.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: goldAccent)),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {bool isNum = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: controller,
        maxLines: lines,
        style: const TextStyle(color: Colors.white),
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        decoration: _inputDecoration(label),
      ),
    );
  }
}