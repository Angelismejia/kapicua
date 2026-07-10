import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PrintService {
  // Se arma según la hoja que pida el diálogo de impresión en ese
  // momento (vertical u horizontal, la que haya elegido la persona), en
  // vez de un tamaño fijo — así, cambiar de orientación en el diálogo
  // del navegador sí ajusta el certificado, llenando la hoja completa
  // sin recortar nada ni dejar espacio en blanco.
  Future<Uint8List> _buildPdf(Uint8List pngBytes, PdfPageFormat format) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (context) =>
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
    return doc.save();
  }

  Future<void> printCertificate(Uint8List pngBytes) async {
    await Printing.layoutPdf(
      onLayout: (format) async => _buildPdf(pngBytes, format),
    );
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
