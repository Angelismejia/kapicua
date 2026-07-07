import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/round.dart';
import '../services/firestore_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'es');

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: StreamBuilder<List<Game>>(
        stream: firestore.watchFinishedGames(),
        builder: (context, gamesSnapshot) {
          final games = gamesSnapshot.data ?? [];
          if (games.isEmpty) {
            return const Center(
              child: Text('Todavía no hay partidas terminadas.'),
            );
          }
          return StreamBuilder<List<Player>>(
            stream: firestore.watchAllPlayers(),
            builder: (context, playersSnapshot) {
              final players = {
                for (final p in playersSnapshot.data ?? <Player>[])
                  p.id: p.displayName,
              };
              return ListView.builder(
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];
                  final teamAName = game.teamAPlayerIds
                      .map((id) => players[id] ?? '...')
                      .join(' y ');
                  final teamBName = game.teamBPlayerIds
                      .map((id) => players[id] ?? '...')
                      .join(' y ');
                  return ListTile(
                    leading: const Icon(Icons.emoji_events),
                    title: Text('$teamAName vs $teamBName'),
                    subtitle: Text(
                      [
                        if (game.finishedAt != null)
                          dateFormat.format(game.finishedAt!),
                        '${game.teamAScore} - ${game.teamBScore}',
                        game.winner == 'A' ? 'Ganó Casa' : 'Ganó Visita',
                      ].join(' · '),
                    ),
                    trailing: Text('Meta ${game.targetScore}'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GameDetailScreen(game: game, players: players),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class GameDetailScreen extends StatelessWidget {
  final Game game;
  final Map<String, String> players;

  const GameDetailScreen({
    super.key,
    required this.game,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final teamAName = game.teamAPlayerIds
        .map((id) => players[id] ?? '...')
        .join(' y ');
    final teamBName = game.teamBPlayerIds
        .map((id) => players[id] ?? '...')
        .join(' y ');

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la partida')),
      body: StreamBuilder<List<Round>>(
        stream: firestore.watchRounds(game.id),
        builder: (context, snapshot) {
          final rounds = snapshot.data ?? [];
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Ronda')),
                DataColumn(label: Text('Casa\n$teamAName')),
                DataColumn(label: Text('Visita\n$teamBName')),
              ],
              rows: [
                ...rounds.map((round) {
                  return DataRow(
                    cells: [
                      DataCell(Text('${round.roundNumber}')),
                      DataCell(Text('${round.teamAPoints}')),
                      DataCell(Text('${round.teamBPoints}')),
                    ],
                  );
                }),
                DataRow(
                  cells: [
                    const DataCell(
                      Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${game.teamAScore}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${game.teamBScore}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
