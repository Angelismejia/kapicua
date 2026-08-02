import 'package:flutter/material.dart';

import 'certificate_positions.dart';

class CertificateWidget extends StatelessWidget {
  final String winnerName;
  final String monthLabel;
  final int totalScore;

  const CertificateWidget({
    super.key,
    required this.winnerName,
    required this.monthLabel,
    required this.totalScore,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: _buildCertificate(context),
    );
  }

  Widget _buildCertificate(BuildContext context) {
    return SizedBox(
      width: CertificatePositions.canvasWidth,
      height: CertificatePositions.canvasHeight,
      child: Stack(
        children: [
          Image.asset(
            'assets/certificado.png',
            width: CertificatePositions.canvasWidth,
            height: CertificatePositions.canvasHeight,
            fit: BoxFit.fill,
          ),
          // Tapa el nombre de ejemplo del diseño original
          Positioned(
            top: CertificatePositions.nameBoxTop,
            left: CertificatePositions.nameBoxLeft,
            width: CertificatePositions.nameBoxWidth,
            height: CertificatePositions.nameBoxHeight,
            child: Container(color: const Color(0xFFFDFCF8)),
          ),
          // Tapa el párrafo de ejemplo del diseño original
          Positioned(
            top: CertificatePositions.paragraphBoxTop,
            left: CertificatePositions.paragraphBoxLeft,
            width: CertificatePositions.paragraphBoxWidth,
            height: CertificatePositions.paragraphBoxHeight,
            child: Container(color: const Color(0xFFFDFCF8)),
          ),
          Positioned(
            top: CertificatePositions.nameBoxTop,
            left: CertificatePositions.nameBoxLeft,
            width: CertificatePositions.nameBoxWidth,
            height: CertificatePositions.nameBoxHeight,
            child: Center(
              child: Text(
                winnerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: CertificatePositions.nameFontFamily,
                  fontSize: CertificatePositions.nameFontSize,
                  color: CertificatePositions.accentColor,
                ),
              ),
            ),
          ),
          Positioned(
            top: CertificatePositions.paragraphBoxTop,
            left: CertificatePositions.paragraphBoxLeft,
            width: CertificatePositions.paragraphBoxWidth,
            height: CertificatePositions.paragraphBoxHeight,
            child: Column(
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily: CertificatePositions.paragraphFontFamily,
                      fontSize: CertificatePositions.paragraphFontSize,
                      color: CertificatePositions.bodyTextColor,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'Por su sobresaliente desempeño el Torneo de Dominó de ',
                      ),
                      TextSpan(
                        text: monthLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: ', logrando un impresionante puntaje de ',
                      ),
                      TextSpan(
                        text: '$totalScore puntos',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text:
                            ', posicionándose como el mejor jugador del mes y superando a '
                            'todos los competidores. Este reconocimiento destaca su estrategia, '
                            'habilidad y dedicación en cada partida.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  '¡Felicidades, campeón!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: CertificatePositions.paragraphFontFamily,
                    fontSize: CertificatePositions.paragraphFontSize,
                    fontWeight: FontWeight.bold,
                    color: CertificatePositions.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
