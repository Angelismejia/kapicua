import 'package:flutter/material.dart';

import 'certificate_positions.dart';

class RunnerUpCertificateWidget extends StatelessWidget {
  final String playerName;
  final String monthLabel;
  final int totalScore;

  const RunnerUpCertificateWidget({
    super.key,
    required this.playerName,
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
      width: RunnerUpCertificatePositions.canvasWidth,
      height: RunnerUpCertificatePositions.canvasHeight,
      child: Stack(
        children: [
          Image.asset(
            'assets/subcampeon.png',
            width: RunnerUpCertificatePositions.canvasWidth,
            height: RunnerUpCertificatePositions.canvasHeight,
            fit: BoxFit.fill,
          ),
          // Tapa el nombre de ejemplo del diseño original
          Positioned(
            top: RunnerUpCertificatePositions.nameBoxTop,
            left: RunnerUpCertificatePositions.nameBoxLeft,
            width: RunnerUpCertificatePositions.nameBoxWidth,
            height: RunnerUpCertificatePositions.nameBoxHeight,
            child: Container(color: Colors.white),
          ),
          // Tapa el párrafo de ejemplo del diseño original
          Positioned(
            top: RunnerUpCertificatePositions.paragraphBoxTop,
            left: RunnerUpCertificatePositions.paragraphBoxLeft,
            width: RunnerUpCertificatePositions.paragraphBoxWidth,
            height: RunnerUpCertificatePositions.paragraphBoxHeight,
            child: Container(color: Colors.white),
          ),
          Positioned(
            top: RunnerUpCertificatePositions.nameBoxTop,
            left: RunnerUpCertificatePositions.nameBoxLeft,
            width: RunnerUpCertificatePositions.nameBoxWidth,
            height: RunnerUpCertificatePositions.nameBoxHeight,
            child: Center(
              child: Text(
                playerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: RunnerUpCertificatePositions.nameFontFamily,
                  fontSize: RunnerUpCertificatePositions.nameFontSize,
                  color: RunnerUpCertificatePositions.accentColor,
                ),
              ),
            ),
          ),
          Positioned(
            top: RunnerUpCertificatePositions.paragraphBoxTop,
            left: RunnerUpCertificatePositions.paragraphBoxLeft,
            width: RunnerUpCertificatePositions.paragraphBoxWidth,
            height: RunnerUpCertificatePositions.paragraphBoxHeight,
            child: Column(
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily:
                          RunnerUpCertificatePositions.paragraphFontFamily,
                      fontSize: RunnerUpCertificatePositions.paragraphFontSize,
                      color: RunnerUpCertificatePositions.bodyTextColor,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'Por su sobresaliente desempeño en el Torneo de Dominó de ',
                      ),
                      TextSpan(
                        text: monthLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: RunnerUpCertificatePositions.accentColor,
                        ),
                      ),
                      const TextSpan(
                        text: ', logrando un impresionante puntaje de ',
                      ),
                      TextSpan(
                        text: '$totalScore puntos',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: RunnerUpCertificatePositions.accentColor,
                        ),
                      ),
                      const TextSpan(
                        text:
                            ', posicionándose como el segundo jugador del mes, '
                            'demostrando habilidad, estrategia y constancia a lo '
                            'largo de cada partida.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                const Text(
                  '¡Felicidades, subcampeón!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: RunnerUpCertificatePositions.paragraphFontFamily,
                    fontSize: RunnerUpCertificatePositions.paragraphFontSize,
                    fontWeight: FontWeight.bold,
                    color: RunnerUpCertificatePositions.accentColor,
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
