import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrintService {
  // Hoja vertical (A4). El certificado se muestra completo, sin recortes,
  // manteniendo su relación de aspecto y centrado en la página.
  Future<Uint8List> _buildPdf(Uint8List pngBytes) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    const page = PdfPageFormat.a4;
    doc.addPage(
      pw.Page(
        pageFormat: page,
        margin: pw.EdgeInsets.zero,
        build: (context) =>
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
    return doc.save();
  }

  Future<void> printCertificate(Uint8List pngBytes) async {
    final bytes = await _buildPdf(pngBytes);
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  Future<void> shareCertificate(Uint8List pngBytes) async {
    final bytes = await _buildPdf(pngBytes);
    await Printing.sharePdf(bytes: bytes, filename: 'certificado_kapicua.pdf');
  }
}
