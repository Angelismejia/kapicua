import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../widgets/certificate/certificate_positions.dart';

class PrintService {
  // Página con la misma proporción del certificado (sin recortes ni bordes)
  // para que se imprima completo, ocupando toda la hoja.
  PdfPageFormat get _certificatePageFormat {
    const ratio = CertificatePositions.canvasHeight / CertificatePositions.canvasWidth;
    final width = PdfPageFormat.a4.landscape.width;
    return PdfPageFormat(width, width * ratio, marginAll: 0);
  }

  Future<Uint8List> _buildPdf(Uint8List pngBytes) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    doc.addPage(
      pw.Page(
        pageFormat: _certificatePageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Image(image, fit: pw.BoxFit.fill),
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
