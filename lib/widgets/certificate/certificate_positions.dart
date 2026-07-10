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
