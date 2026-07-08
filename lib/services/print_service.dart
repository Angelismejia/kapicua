import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PrintService {
  // Hoja vertical (A4). El certificado es una imagen apaisada (más ancha
  // que alta), así que la rotamos 90° para que llene la hoja vertical de
  // borde a borde, sin recortar nada ni dejar espacio en blanco.
  Future<Uint8List> _buildPdf(Uint8List pngBytes) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    const page = PdfPageFormat.a4;
    doc.addPage(
      pw.Page(
        pageFormat: page,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Center(
          child: pw.Transform.rotateBox(
            angle: math.pi / 2,
            child: pw.SizedBox(
              width: page.height,
              height: page.width,
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        ),
      ),
    );
    return doc.save();
  }

  Future<void> printCertificate(Uint8List pngBytes) async {
    final bytes = await _buildPdf(pngBytes);
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  Future<void> shareCertificate(Uint8List pngBytes) async {
    await SharePlus.instance.share(
      ShareParams(
        text: '¡Mira mi certificado de campeón en Kapicua!',
        files: [
          XFile.fromData(
            pngBytes,
            name: 'certificado_kapicua.png',
            mimeType: 'image/png',
          ),
        ],
      ),
    );
  }
}
