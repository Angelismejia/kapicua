import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';

import '../widgets/certificate/certificate_positions.dart';

class CertificateService {
  Future<Uint8List> capture(GlobalKey repaintKey) async {
    final boundary =
        repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: CertificatePositions.capturePixelRatio,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> downloadToGallery(Uint8List pngBytes) async {
    await Gal.putImageBytes(pngBytes, name: 'certificado_kapicua');
  }
}
