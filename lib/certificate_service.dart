import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:permission_handler/permission_handler.dart';

class CertificateService {
  static Future<void> generateCertificate({
    required BuildContext context,
    required String userName,
    required String courseTitle,
    required String templatePath, // This will receive certificateTemplateUrl
    required String profileImageUrl,
    required String enrollmentDate,
  }) async {
    
    // --- 1. START LOADER IMMEDIATELY ---
    // We start the loader first so the user sees instant feedback.
    ValueNotifier<bool> isDone = ValueNotifier(false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Material(
        color: Colors.transparent,
        child: Center(
          child: ValueListenableBuilder(
            valueListenable: isDone,
            builder: (context, done, _) {
              return Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A), 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: done ? Colors.greenAccent : const Color(0xFFD4A373),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    done 
                      ? const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 70)
                      : LoadingAnimationWidget.staggeredDotsWave(color: const Color(0xFFD4A373), size: 50),
                    const SizedBox(height: 20),
                    Text(
                      done ? "SAVED TO GALLERY!" : "GENERATING...",
                      style: GoogleFonts.montserrat(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    try {
      // --- 2. PERMISSION CHECK ---
      // Triggering permission request while loader is spinning. 
      // Using a simple request to avoid SDK-level freezes.
      await [Permission.storage, Permission.photos].request();

      // --- 3. ASSET FETCHING ---
      debugPrint("Fetching: $templatePath");
      final templateRes = await http.get(Uri.parse(templatePath)).timeout(const Duration(seconds: 15));
      final profileRes = await http.get(Uri.parse(profileImageUrl)).timeout(const Duration(seconds: 15));
      final ttf = await PdfGoogleFonts.montserratBold();

      if (templateRes.statusCode != 200) throw Exception("Template download failed");

      // --- 4. PDF COMPOSITION ---
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) => pw.Stack(
            children: [
              pw.FullPage(
                ignoreMargins: true, 
                child: pw.Image(pw.MemoryImage(templateRes.bodyBytes), fit: pw.BoxFit.fill),
              ),
              // User Profile Image
              pw.Positioned(
                top: 195, left: 235,
                child: pw.Container(
                  width: 78, height: 104,
                  child: pw.Image(pw.MemoryImage(profileRes.bodyBytes), fit: pw.BoxFit.cover),
                ),
              ),
              // User Name
              pw.Positioned(
                top: 320, left: 70, right: 520,
                child: pw.Center(
                  child: pw.Text(
                    userName.toUpperCase(), 
                    style: pw.TextStyle(font: ttf, fontSize: 22, color: PdfColors.black),
                  ),
                ),
              ),
              // Enrollment Date
              pw.Positioned(
                top: 455, left: 175,
                child: pw.Text(
                  enrollmentDate, 
                  style: pw.TextStyle(font: ttf, fontSize: 16, color: PdfColors.black),
                ),
              ),
            ],
          ),
        ),
      );

      // --- 5. RASTERIZE & FILE SAVE ---
      final pdfBytes = await pdf.save();
      final images = Printing.raster(pdfBytes, pages: [0], dpi: 300);
      final imageList = await images.toList();
      final pngBytes = await imageList[0].toPng();

      final tempDir = await getTemporaryDirectory();
      final String fullPath = '${tempDir.path}/cert_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(fullPath);
      await file.writeAsBytes(pngBytes);

      // --- 6. GALLERY INTEGRATION ---
      // Gal triggers its own internal permission bridge if the above check was bypassed
      await Gal.putImage(fullPath);

      // --- 7. FINALIZE ---
      isDone.value = true;
      HapticFeedback.heavyImpact();
      
      await Future.delayed(const Duration(milliseconds: 2000));
      if (context.mounted) Navigator.pop(context); // Close Loader

    } catch (e) {
      debugPrint("CERTIFICATE_SERVICE_ERROR: $e");
      if (context.mounted) {
        Navigator.pop(context); // Close Loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}