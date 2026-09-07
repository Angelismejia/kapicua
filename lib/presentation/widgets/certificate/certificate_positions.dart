import 'package:flutter/material.dart';

/// Medidas de assets/certificado.png (1492x1054), tomadas a mano sobre la
/// plantilla.
class CertificatePositions {
  static const double canvasWidth = 1492;
  static const double canvasHeight = 1054;

  // Más bajo que 2.0 = imagen más liviana = el navegador tarda menos en
  // "dibujar" el PDF antes de poder imprimir, sin perder nitidez notoria.
  static const double capturePixelRatio = 1.5;

  static const Color accentColor = Color(0xFF16302A);
  static const Color bodyTextColor = Color(0xFF1A1A22);

  static const double nameBoxTop = 388;
  static const double nameBoxLeft = 260;
  static const double nameBoxWidth = 970;
  static const double nameBoxHeight = 190;
  static const String nameFontFamily = 'AlexBrush';
  static const double nameFontSize = 68;

  // La plantilla trae una rayita dorada bajo el nombre, pero el recuadro que
  // tapa el nombre de ejemplo la borra (los rabitos de las letras bajan hasta
  // pasarla), así que hay que volver a dibujarla en el mismo sitio.
  static const Color dividerColor = Color(0xFFB99355);
  static const double dividerTop = 549;
  static const double dividerLeft = 400;
  static const double dividerWidth = 690;
  static const double dividerHeight = 24;
  static const double dividerLineThickness = 2;
  static const double dividerDiamondSize = 15;
  static const double dividerDiamondGap = 10;

  // Cubre el párrafo y la línea "¡Felicidades, campeón!" juntos.
  static const double paragraphBoxTop = 583;
  static const double paragraphBoxLeft = 260;
  static const double paragraphBoxWidth = 970;
  static const double paragraphBoxHeight = 228;
  static const String paragraphFontFamily = 'AlegreyaSans';
  static const double paragraphFontSize = 20;
}

/// Medidas de assets/subcampeon.png (1536x1024), tomadas a mano sobre la
/// plantilla igual que se hizo para CertificatePositions.
class RunnerUpCertificatePositions {
  static const double canvasWidth = 1536;
  static const double canvasHeight = 1024;

  static const double capturePixelRatio = 1.5;

  static const Color accentColor = Color(0xFF0A285C);
  static const Color bodyTextColor = Color(0xFF161814);

  static const double nameBoxTop = 380;
  static const double nameBoxLeft = 300;
  static const double nameBoxWidth = 940;
  static const double nameBoxHeight = 110;
  static const String nameFontFamily = 'AlexBrush';
  static const double nameFontSize = 70;

  // Cubre el párrafo y la línea "¡Felicidades, segundo lugar!" juntos,
  // igual que CertificatePositions cubre el párrafo y "¡Felicidades,
  // campeón!" en un solo bloque.
  static const double paragraphBoxTop = 510;
  static const double paragraphBoxLeft = 280;
  static const double paragraphBoxWidth = 980;
  static const double paragraphBoxHeight = 270;
  static const String paragraphFontFamily = 'AlegreyaSans';
  static const double paragraphFontSize = 24;
}
