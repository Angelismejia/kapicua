import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PrintService {
  // El navegador nunca vuelve a pedir el PDF si cambias vertical/
  // horizontal ya dentro de su propio diálogo de impresión (ese
  // interruptor solo decide cómo acomodar la hoja fija que ya se le
  // entregó, no puede regresar a pedirle otra a Flutter). Por eso el
  // PDF se arma siempre horizontal de una vez — el certificado es una
  // imagen apaisada, así que esta es su forma natural — y así llena la
  // hoja completa sin importar qué tan orientado esté el diálogo.
  Future<Uint8List> _buildPdf(Uint8List pngBytes, PdfPageFormat format) async {
    final doc = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    doc.addPage(
      pw.Page(
        pageFormat: format.landscape,
        margin: pw.EdgeInsets.zero,
        build: (context) =>
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
    return doc.save();
  }

  Future<void> printCertificate(Uint8List pngBytes) async {
    final bytes = await _buildPdf(pngBytes, PdfPageFormat.a4);
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
