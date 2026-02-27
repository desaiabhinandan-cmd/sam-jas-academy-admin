import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class PDFViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PDFViewerScreen({super.key, required this.url, required this.title});

  @override
  _PDFViewerScreenState createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  String localPath = "";
  bool isLoading = true;
  int totalPages = 0;
  int currentPage = 0;
  bool isReady = false;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      final dir = await getApplicationDocumentsDirectory();
      
      // Use a unique name based on the title to avoid caching issues
      final fileName = widget.title.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final file = File('${dir.path}/$fileName.pdf');

      await file.writeAsBytes(response.bodyBytes, flush: true);
      
      if (mounted) {
        setState(() {
          localPath = file.path;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading PDF: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color goldAccent = const Color(0xFFD4A373);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        centerTitle: true,
        // DYNAMIC TITLE LOGIC
        title: Text(
          widget.title.toUpperCase(),
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: goldAccent,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: goldAccent, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (!isLoading)
            PDFView(
              filePath: localPath,
              enableSwipe: true,
              swipeHorizontal: false, // Vertical scroll is crisper for reading
              autoSpacing: true,
              pageFling: true,
              onRender: (pages) {
                setState(() {
                  totalPages = pages!;
                  isReady = true;
                });
              },
              onPageChanged: (page, total) {
                setState(() {
                  currentPage = page!;
                });
              },
            ),
          
          // CRISP LOADING STATE
          if (isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: goldAccent, strokeWidth: 2),
                  const SizedBox(height: 20),
                  Text(
                    "FETCHING NOTES...",
                    style: GoogleFonts.montserrat(
                      color: goldAccent.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

          // PAGE INDICATOR BADGE
          if (isReady)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: goldAccent.withOpacity(0.3), width: 0.5),
                ),
                child: Text(
                  "PAGE ${currentPage + 1} / $totalPages",
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}