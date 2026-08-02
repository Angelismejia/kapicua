import 'package:flutter/material.dart';

class CertificatePositions {
  static const double canvasWidth = 1079;
  static const double canvasHeight = 767;

  // Más bajo que 2.0 = imagen más liviana = el navegador tarda menos en
  // "dibujar" el PDF antes de poder imprimir, sin perder nitidez notoria.
  static const double capturePixelRatio = 1.5;

  static const Color textColor = Color(0xFF20443B);

  static const double nameBoxTop = 320;
  static const double nameBoxLeft = 150;
  static const double nameBoxWidth = 780;
  static const double nameBoxHeight = 85;
  static const String nameFontFamily = 'AlexBrush';
  static const double nameFontSize = 50;

  static const double paragraphBoxTop = 405;
  static const double paragraphBoxLeft = 215;
  static const double paragraphBoxWidth = 650;
  static const double paragraphBoxHeight = 155;
  static const String paragraphFontFamily = 'AlegreyaSans';
  static const double paragraphFontSize = 17;
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
