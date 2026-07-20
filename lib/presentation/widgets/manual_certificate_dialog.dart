import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/player.dart';
import '../screens/certificate_screen.dart';

void showManualCertificateDialog(BuildContext context, List<Player> players) {
  Player? selectedPlayer = players.isNotEmpty ? players.first : null;
  final nameController = TextEditingController();
  final monthController = TextEditingController(
    text: DateFormat('MMMM yyyy', 'es').format(DateTime.now()),
  );
  final scoreController = TextEditingController();
  var useCustomName = players.isEmpty;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Certificado manual'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (players.isNotEmpty) ...[
                DropdownButtonFormField<Player>(
                  initialValue: useCustomName ? null : selectedPlayer,
                  decoration: const InputDecoration(labelText: 'Jugador'),
                  items: players
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p, child: Text(p.fullName)),
                      )
                      .toList(),
                  onChanged: (p) => setState(() {
                    selectedPlayer = p;
                    useCustomName = false;
                  }),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Escribir otro nombre'),
                  value: useCustomName,
                  onChanged: (v) => setState(() => useCustomName = v ?? false),
                ),
              ],
              if (useCustomName || players.isEmpty)
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del ganador',
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: monthController,
                decoration: const InputDecoration(
                  labelText: 'Mes (ej. Junio 2026)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scoreController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Puntaje'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = useCustomName || players.isEmpty
                  ? nameController.text.trim()
                  : (selectedPlayer?.fullName ?? '');
              final month = monthController.text.trim();
              final score = int.tryParse(scoreController.text.trim()) ?? 0;
              if (name.isEmpty || month.isEmpty) return;
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CertificateScreen(
                    winnerName: name,
                    monthLabel: month,
                    totalScore: score,
                  ),
                ),
              );
            },
            child: const Text('Generar'),
          ),
        ],
      ),
    ),
  );
}
