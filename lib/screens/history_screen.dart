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
            return const Center(child: Text('Todavía no hay partidas terminadas.'));
          }
          return StreamBuilder<List<Player>>(
            stream: firestore.watchAllPlayers(),
            builder: (context, playersSnapshot) {
              final players = {for (final p in playersSnapshot.data ?? <Player>[]) p.id: p.displayName};
              return ListView.builder(
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];
                  final winnerName = players[game.winnerId] ?? '...';
                  return ListTile(
                    leading: const Icon(Icons.emoji_events),
                    title: Text(winnerName),
                    subtitle: Text(game.finishedAt == null
                        ? ''
                        : dateFormat.format(game.finishedAt!)),
                    trailing: Text('Meta ${game.targetScore}'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameDetailScreen(game: game, players: players),
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

  const GameDetailScreen({super.key, required this.game, required this.players});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

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
                ...game.participantIds.map((id) => DataColumn(label: Text(players[id] ?? '...'))),
              ],
              rows: rounds.map((round) {
                return DataRow(cells: [
                  DataCell(Text('${round.roundNumber}')),
                  ...game.participantIds.map((id) => DataCell(Text('${round.points[id] ?? 0}'))),
                ]);
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
