import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../models/player_stats.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/monthly_winner.dart';
import '../widgets/manual_certificate_dialog.dart';
import '../widgets/monthly_winner_card.dart';
import '../widgets/player_stat_history_dialog.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final isAdmin = context.watch<AuthService>().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium_outlined),
            tooltip: 'Generar certificado manual',
            onPressed: () async {
              final players = await firestore.watchAllPlayers().first;
              if (!context.mounted) return;
              showManualCertificateDialog(context, players);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Player>>(
        stream: firestore.watchAllPlayers(),
        builder: (context, playersSnapshot) {
          final players = playersSnapshot.data ?? [];
          return StreamBuilder<List<PlayerStatEntry>>(
            stream: firestore.watchAllStatEntries(),
            builder: (context, entriesSnapshot) {
              final entries = entriesSnapshot.data ?? [];

              final stats =
                  players.map((player) {
                    var won = 0;
                    var lost = 0;
                    for (final e in entries) {
                      if (e.playerId != player.id) continue;
                      if (e.isWin) {
                        won++;
                      } else {
                        lost++;
                      }
                    }
                    return PlayerStats(
                      player: player,
                      gamesWon: won,
                      gamesLost: lost,
                    );
                  }).toList()..sort(
                    (a, b) => b.winPercentage.compareTo(a.winPercentage),
                  );

              final monthlyWinner = computeMonthlyWinner(
                entries,
                players,
                DateTime.now(),
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (monthlyWinner != null)
                    MonthlyWinnerCard(result: monthlyWinner),
                  const SizedBox(height: 16),
                  Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        horizontalMargin: 12,
                        columns: const [
                          DataColumn(label: Text('Jugador')),
                          DataColumn(label: Text('Gan.'), numeric: true),
                          DataColumn(label: Text('Perd.'), numeric: true),
                          DataColumn(label: Text('Total'), numeric: true),
                          DataColumn(label: Text('%'), numeric: true),
                        ],
                        rows: stats.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  s.player.displayName,
                                  style: const TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                onTap: () => showPlayerStatHistoryDialog(
                                  context,
                                  firestore,
                                  s.player,
                                  isAdmin,
                                ),
                              ),
                              DataCell(Text('${s.gamesWon}')),
                              DataCell(Text('${s.gamesLost}')),
                              DataCell(Text('${s.gamesPlayed}')),
                              DataCell(
                                Text('${s.winPercentage.toStringAsFixed(1)}%'),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca el nombre de un jugador para ver su historial'
                    '${isAdmin ? ' y agregar ganadas o perdidas' : ''}.',
                    style: Theme.of(context).textTheme.bodySmall,
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
