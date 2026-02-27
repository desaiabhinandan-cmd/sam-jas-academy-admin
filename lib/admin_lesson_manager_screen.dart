import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

class AdminLessonManagerScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const AdminLessonManagerScreen({
    super.key, 
    required this.courseId, 
    required this.courseTitle
  });

  @override
  _AdminLessonManagerScreenState createState() => _AdminLessonManagerScreenState();
}

class _AdminLessonManagerScreenState extends State<AdminLessonManagerScreen> {
  final Color goldAccent = const Color(0xFFD4A373);
  final Color charcoalBg = const Color(0xFF121212);
  bool _isSyncing = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();

  TextStyle montStyle({double size = 14, FontWeight weight = FontWeight.normal, Color color = Colors.white}) {
    return GoogleFonts.montserrat(fontSize: size, fontWeight: weight, color: color);
  }

  // --- NEW: BULK SYNC FROM EXCEL ---
  Future<void> _syncFromExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      setState(() => _isSyncing = true);
      try {
        var bytes = File(result.files.single.path!).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        for (var table in excel.tables.keys) {
          var rows = excel.tables[table]!.rows;
          // Start from index 1 to skip headers
          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            if (row.isEmpty) continue;

            // Mapping: A:DocID, B:order, C:title, D:videoUrl, E:duration, F:description
            String? docId = row[0]?.value?.toString();
            int order = int.tryParse(row[1]?.value?.toString() ?? '0') ?? 0;
            String title = row[2]?.value?.toString() ?? '';
            String videoUrl = row[3]?.value?.toString() ?? '';
            String duration = row[4]?.value?.toString() ?? '';
            String description = row[5]?.value?.toString() ?? '';

            if (title.isEmpty) continue; // Skip empty rows

            final Map<String, dynamic> lessonData = {
              'order': order,
              'title': title,
              'videoUrl': videoUrl,
              'duration': duration,
              'description': description,
            };

            final lessonsRef = FirebaseFirestore.instance
                .collection('courses')
                .doc(widget.courseId)
                .collection('lessons');

            if (docId != null && docId.trim().isNotEmpty) {
              // Update existing
              await lessonsRef.doc(docId.trim()).set(lessonData, SetOptions(merge: true));
            } else {
              // Add new
              await lessonsRef.add(lessonData);
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Curriculum Synced!")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _saveLesson({String? lessonId}) async {
    if (_titleController.text.isEmpty || _videoUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title and Video URL are required")));
      return;
    }

    final Map<String, dynamic> lessonData = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'videoUrl': _videoUrlController.text.trim(),
      'duration': _durationController.text.trim(),
      'order': int.tryParse(_orderController.text) ?? 0,
    };

    final CollectionReference lessonsRef = FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .collection('lessons');

    if (lessonId == null) {
      await lessonsRef.add(lessonData);
    } else {
      await lessonsRef.doc(lessonId).update(lessonData);
    }

    if (mounted) Navigator.pop(context);
    _clearInputs();
  }

  void _clearInputs() {
    _titleController.clear();
    _descController.clear();
    _videoUrlController.clear();
    _durationController.clear();
    _orderController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: charcoalBg,
      appBar: AppBar(
        title: Text(widget.courseTitle.toUpperCase(), style: montStyle(size: 14, weight: FontWeight.bold)),
        backgroundColor: charcoalBg,
        iconTheme: IconThemeData(color: goldAccent),
        actions: [
          _isSyncing 
            ? const Padding(padding: EdgeInsets.all(15), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : IconButton(
                onPressed: _syncFromExcel, 
                icon: const Icon(Icons.cloud_upload_outlined, color: Colors.greenAccent),
                tooltip: "Upload/Sync Curriculum",
              )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: goldAccent,
        onPressed: () => _showLessonSheet(),
        child: const Icon(Icons.video_call, color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('lessons')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          if (snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No lessons added yet", style: montStyle(color: Colors.white54)));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: goldAccent.withOpacity(0.1),
                  child: Text("${data['order']}", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
                ),
                title: Text(data['title'] ?? '', style: montStyle(weight: FontWeight.bold)),
                subtitle: Text(data['duration'] ?? 'No duration', style: montStyle(size: 12, color: Colors.white60)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                      onPressed: () => _showLessonSheet(lessonId: doc.id, data: data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => doc.reference.delete(),
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

  void _showLessonSheet({String? lessonId, Map<String, dynamic>? data}) {
    if (lessonId != null && data != null) {
      _titleController.text = data['title'] ?? '';
      _descController.text = data['description'] ?? '';
      _videoUrlController.text = data['videoUrl'] ?? '';
      _durationController.text = data['duration'] ?? '';
      _orderController.text = data['order']?.toString() ?? '0';
    } else {
      _clearInputs();
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lessonId == null ? "ADD LESSON" : "EDIT LESSON", 
                style: montStyle(size: 16, weight: FontWeight.bold, color: goldAccent)),
              const SizedBox(height: 10),
              _buildField(_titleController, "Lesson Title (e.g. Intro to Skin)"),
              _buildField(_orderController, "Sequence Order (1, 2, 3...)", isNum: true),
              _buildField(_durationController, "Duration (e.g. 10:45)"),
              _buildField(_videoUrlController, "Video URL"),
              _buildField(_descController, "Lesson Description", lines: 3),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldAccent, 
                  minimumSize: const Size(double.infinity, 50)
                ),
                onPressed: () => _saveLesson(lessonId: lessonId),
                child: Text("SAVE LESSON", style: montStyle(color: Colors.black, weight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
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
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: goldAccent.withOpacity(0.2))),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: goldAccent)),
        ),
      ),
    );
  }
}