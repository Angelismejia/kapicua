import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/rule.dart';

const _kPdfGreen = PdfColor.fromInt(0xFF2E6B3F);
const _kPdfLightGreen = PdfColor.fromInt(0xFFEAF6EB);

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
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.cover)),
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

  // Reglas como PDF en vez de imagen: con una liga que ya acumula muchas
  // reglas, una sola imagen larga obliga a hacer scroll infinito para
  // leerla. Un PDF las reparte solo en varias páginas.
  Future<Uint8List> _buildRulesPdf(List<Rule> ruleList) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
    );
    final medium = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Poppins-Medium.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'),
    );

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(font: regular, fontSize: 9, color: _kPdfGreen),
          ),
        ),
        build: (context) => [
          pw.Text(
            'KAPICUA',
            style: pw.TextStyle(
              font: bold,
              fontSize: 11,
              letterSpacing: 3,
              color: _kPdfGreen,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Reglas de la liga',
            style: pw.TextStyle(font: bold, fontSize: 22),
          ),
          pw.SizedBox(height: 10),
          pw.Container(width: 44, height: 3, color: _kPdfGreen),
          pw.SizedBox(height: 18),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _kPdfLightGreen,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '"Por eso, ya sea que estén comiendo, bebiendo o haciendo '
                  'cualquier otra cosa, háganlo todo para la gloria de Dios."',
                  style: pw.TextStyle(
                    font: regular,
                    fontStyle: pw.FontStyle.italic,
                    fontSize: 11,
                    lineSpacing: 3,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '— 1 Corintios 10:31',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 9.5,
                      color: _kPdfGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          for (var i = 0; i < ruleList.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 14),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 20,
                    height: 20,
                    alignment: pw.Alignment.center,
                    decoration: const pw.BoxDecoration(
                      color: _kPdfLightGreen,
                      shape: pw.BoxShape.circle,
                    ),
                    child: pw.Text(
                      '${i + 1}',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 10,
                        color: _kPdfGreen,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Text(
                      ruleList[i].text,
                      style: pw.TextStyle(font: medium, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> shareRules(List<Rule> ruleList) async {
    final bytes = await _buildRulesPdf(ruleList);
    await SharePlus.instance.share(
      ShareParams(
        text: 'Reglas de la liga en Kapicua',
        files: [
          XFile.fromData(
            bytes,
            name: 'reglas_kapicua.pdf',
            mimeType: 'application/pdf',
          ),
        ],
      ),
    );
  }
}
