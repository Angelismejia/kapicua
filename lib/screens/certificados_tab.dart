import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../services/firestore_service.dart';
import '../utils/monthly_winner.dart';
import '../widgets/manual_certificate_dialog.dart';
import '../widgets/monthly_winner_card.dart';

class CertificadosTab extends StatelessWidget {
  const CertificadosTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Certificados')),
      body: StreamBuilder<List<Player>>(
        stream: firestore.watchAllPlayers(),
        builder: (context, playersSnap) {
          final players = playersSnap.data ?? [];
          return StreamBuilder<List<PlayerStatEntry>>(
            stream: firestore.watchAllStatEntries(),
            builder: (context, entriesSnap) {
              final entries = entriesSnap.data ?? [];
              final monthlyWinner = computeMonthlyWinner(
                entries,
                players,
                DateTime.now(),
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (monthlyWinner != null)
                    MonthlyWinnerCard(result: monthlyWinner)
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Todavía no hay partidas ganadas este mes.',
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    '¿Necesitas otro certificado?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Genera uno manualmente con cualquier nombre, mes o puntaje.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.edit_document),
                    label: const Text('Certificado manual'),
                    onPressed: () =>
                        showManualCertificateDialog(context, players),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
