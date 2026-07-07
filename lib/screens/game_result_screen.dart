import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../services/firestore_service.dart';
import 'main_shell.dart';

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
              final players = {
                for (final p in playersSnapshot.data ?? <Player>[])
                  p.id: p.displayName,
              };
              final teamAName = game.teamAPlayerIds
                  .map((id) => players[id] ?? '...')
                  .join(' y ');
              final teamBName = game.teamBPlayerIds
                  .map((id) => players[id] ?? '...')
                  .join(' y ');
              final winnerName = game.winner == 'A' ? teamAName : teamBName;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 64,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¡$winnerName ganó la partida!',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: [
                          Card(
                            child: ListTile(
                              leading: const CircleAvatar(child: Text('C')),
                              title: const Text('Casa'),
                              subtitle: Text(teamAName),
                              trailing: Text(
                                '${game.teamAScore}',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                          ),
                          Card(
                            child: ListTile(
                              leading: const CircleAvatar(child: Text('V')),
                              title: const Text('Visita'),
                              subtitle: Text(teamBName),
                              trailing: Text(
                                '${game.teamBScore}',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const MainShell()),
                          (route) => false,
                        ),
                        child: const Text('Volver al inicio'),
                      ),
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
