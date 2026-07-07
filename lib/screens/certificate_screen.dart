import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/certificate_service.dart';
import '../services/print_service.dart';
import '../widgets/certificate/certificate_widget.dart';

class CertificateScreen extends StatefulWidget {
  final String winnerName;
  final String monthLabel;
  final int totalScore;

  const CertificateScreen({
    super.key,
    required this.winnerName,
    required this.monthLabel,
    required this.totalScore,
  });

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final CertificateService _certificateService = CertificateService();
  final PrintService _printService = PrintService();
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificado de campeón'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Descargar imagen',
            onPressed: _working ? null : _download,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: CertificateWidget(
                      winnerName: widget.winnerName,
                      monthLabel: widget.monthLabel,
                      totalScore: widget.totalScore,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : _share,
                    icon: const Icon(Icons.share),
                    label: const Text('Compartir'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _working ? null : _print,
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimir'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _print() async {
    setState(() => _working = true);
    try {
      final bytes = await _certificateService.capture(_repaintKey);
      await _printService.printCertificate(bytes);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _share() async {
    setState(() => _working = true);
    try {
      final bytes = await _certificateService.capture(_repaintKey);
      await _printService.shareCertificate(bytes);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _download() async {
    setState(() => _working = true);
    try {
      final bytes = await _certificateService.capture(_repaintKey);
      await _certificateService.downloadToGallery(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Certificado descargado'
                  : 'Certificado guardado en tu galería',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
