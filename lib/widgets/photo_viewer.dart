import 'dart:convert';

import 'package:flutter/material.dart';

/// Abre la foto de perfil ampliada a pantalla completa, con zoom tipo
/// WhatsApp (pellizcar para acercar, tocar fuera o la X para cerrar).
void showFullPhoto(BuildContext context, String photoBase64) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _PhotoViewerScreen(photoBase64: photoBase64),
        );
      },
    ),
  );
}

class _PhotoViewerScreen extends StatelessWidget {
  final String photoBase64;

  const _PhotoViewerScreen({required this.photoBase64});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: Image.memory(base64Decode(photoBase64)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
