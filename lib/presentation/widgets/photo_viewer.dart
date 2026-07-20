import 'dart:convert';

import 'package:flutter/material.dart';

/// Abre la foto de perfil ampliada, en un círculo grande (como al tocar
/// una foto de perfil en WhatsApp), con zoom (pellizcar para acercar,
/// tocar fuera o la X para cerrar).
void showFullPhoto(BuildContext context, String photoBase64) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _PhotoViewerScreen(photoBase64: photoBase64, animation: animation);
      },
    ),
  );
}

class _PhotoViewerScreen extends StatelessWidget {
  final String photoBase64;
  final Animation<double> animation;

  const _PhotoViewerScreen({required this.photoBase64, required this.animation});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final diameter = (size.shortestSide * 0.8).clamp(220.0, 380.0);
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: curved,
                  child: Container(
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: GestureDetector(
                        onTap: () {},
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.memory(
                            base64Decode(photoBase64),
                            fit: BoxFit.cover,
                            width: diameter,
                            height: diameter,
                          ),
                        ),
                      ),
                    ),
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
