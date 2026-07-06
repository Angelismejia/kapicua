import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import 'stats_screen.dart';

class GameResultScreen extends StatelessWidget {
  final String gameId;

  const GameResultScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: StreamBuilder<Game?>(
        stream: firestore.watchGame(gameId),
        builder: (context, gameSnapshot) {
          final game = gameSnapshot.data;
          if (game == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<Player>>(
            stream: firestore.watchAllPlayers(),
            builder: (context, playersSnapshot) {
              final players = {for (final p in playersSnapshot.data ?? <Player>[]) p.id: p.displayName};
              final winnerName = players[game.winnerId] ?? '...';
              final entries = game.scores.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.emoji_events, size: 64, color: Colors.amber.shade700),
                    const SizedBox(height: 8),
                    Text('¡$winnerName ganó la partida!',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return ListTile(
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(players[entry.key] ?? '...'),
                            trailing: Text('${entry.value}'),
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const HomeScreen()),
                              (route) => false,
                            ),
                            child: const Text('Volver al inicio'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const StatsScreen()),
                              (route) => false,
                            ),
                            child: const Text('Ver estadísticas'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
