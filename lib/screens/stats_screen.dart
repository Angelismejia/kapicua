import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/player_stats.dart';
import '../services/firestore_service.dart';
import 'certificate_screen.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

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
              _showManualCertificateDialog(context, players);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Player>>(
        stream: firestore.watchAllPlayers(),
        builder: (context, playersSnapshot) {
          final players = playersSnapshot.data ?? [];
          return StreamBuilder<List<Game>>(
            stream: firestore.watchAllFinishedGamesForStats(),
            builder: (context, gamesSnapshot) {
              final games = gamesSnapshot.data ?? [];

              final stats = players.map((player) {
                var won = 0;
                var lost = 0;
                for (final game in games) {
                  if (!game.participantIds.contains(player.id)) continue;
                  if (game.winnerId == player.id) {
                    won++;
                  } else {
                    lost++;
                  }
                }
                return PlayerStats(player: player, gamesWon: won, gamesLost: lost);
              }).toList()
                ..sort((a, b) => b.winPercentage.compareTo(a.winPercentage));

              final monthlyWinner = _computeMonthlyWinner(games, players, DateTime.now());

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (monthlyWinner != null) _MonthlyWinnerCard(result: monthlyWinner),
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
                          return DataRow(cells: [
                            DataCell(Text(s.player.displayName)),
                            DataCell(Text('${s.gamesWon}')),
                            DataCell(Text('${s.gamesLost}')),
                            DataCell(Text('${s.gamesPlayed}')),
                            DataCell(Text('${s.winPercentage.toStringAsFixed(1)}%')),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  MonthlyWinnerResult? _computeMonthlyWinner(List<Game> games, List<Player> players, DateTime month) {
    final gamesThisMonth = games.where((g) =>
        g.finishedAt != null &&
        g.finishedAt!.year == month.year &&
        g.finishedAt!.month == month.month);

    final winsCount = <String, int>{};
    final scoreSum = <String, int>{};
    for (final game in gamesThisMonth) {
      final winnerId = game.winnerId;
      if (winnerId == null) continue;
      winsCount[winnerId] = (winsCount[winnerId] ?? 0) + 1;
      scoreSum[winnerId] = (scoreSum[winnerId] ?? 0) + (game.scores[winnerId] ?? 0);
    }
    if (winsCount.isEmpty) return null;

    String bestId = winsCount.keys.first;
    for (final id in winsCount.keys) {
      final betterWins = winsCount[id]! > winsCount[bestId]!;
      final tiedWinsHigherScore =
          winsCount[id] == winsCount[bestId] && (scoreSum[id] ?? 0) > (scoreSum[bestId] ?? 0);
      if (betterWins || tiedWinsHigherScore) bestId = id;
    }

    final player = players.where((p) => p.id == bestId).cast<Player?>().firstWhere((_) => true, orElse: () => null);
    if (player == null) return null;

    return MonthlyWinnerResult(
      player: player,
      month: month,
      wins: winsCount[bestId]!,
      totalScore: scoreSum[bestId]!,
    );
  }

  void _showManualCertificateDialog(BuildContext context, List<Player> players) {
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
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.fullName)))
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
                    decoration: const InputDecoration(labelText: 'Nombre del ganador'),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: monthController,
                  decoration: const InputDecoration(labelText: 'Mes (ej. Junio 2026)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: scoreController,
                  keyboardType: TextInputType.number,
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
}

class MonthlyWinnerResult {
  final Player player;
  final DateTime month;
  final int wins;
  final int totalScore;

  MonthlyWinnerResult({
    required this.player,
    required this.month,
    required this.wins,
    required this.totalScore,
  });
}

class _MonthlyWinnerCard extends StatelessWidget {
  final MonthlyWinnerResult result;

  const _MonthlyWinnerCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'es').format(result.month);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ganador del mes ($monthLabel)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(result.player.displayName, style: Theme.of(context).textTheme.headlineSmall),
            Text('${result.wins} partidas ganadas · ${result.totalScore} puntos'),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.workspace_premium),
              label: const Text('Generar certificado'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CertificateScreen(
                    winnerName: result.player.fullName,
                    monthLabel: monthLabel,
                    totalScore: result.totalScore,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
