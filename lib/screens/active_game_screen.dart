import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../services/firestore_service.dart';
import 'game_result_screen.dart';

class ActiveGameScreen extends StatefulWidget {
  final String gameId;

  const ActiveGameScreen({super.key, required this.gameId});

  @override
  State<ActiveGameScreen> createState() => _ActiveGameScreenState();
}

class _ActiveGameScreenState extends State<ActiveGameScreen> {
  bool _navigatedToResult = false;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Partida en curso')),
      body: StreamBuilder<Game?>(
        stream: firestore.watchGame(widget.gameId),
        builder: (context, gameSnapshot) {
          final game = gameSnapshot.data;
          if (game == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (game.isFinished && !_navigatedToResult) {
            _navigatedToResult = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => GameResultScreen(gameId: game.id)),
              );
            });
          }

          return StreamBuilder<List<Player>>(
            stream: firestore.watchAllPlayers(),
            builder: (context, playersSnapshot) {
              final players = {for (final p in playersSnapshot.data ?? <Player>[]) p.id: p.displayName};

              final entries = game.scores.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meta: ${game.targetScore} puntos',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Ronda ${game.roundCount}'),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Text('${index + 1}')),
                              title: Text(players[entry.key] ?? '...'),
                              trailing: Text(
                                '${entry.value}',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoundDialog(context, firestore),
        icon: const Icon(Icons.add),
        label: const Text('Agregar ronda'),
      ),
    );
  }

  void _showRoundDialog(BuildContext context, FirestoreService firestore) async {
    final gameSnapshotStream = firestore.watchGame(widget.gameId);
    final game = await gameSnapshotStream.first;
    final playersSnapshotStream = firestore.watchAllPlayers();
    final players = await playersSnapshotStream.first;
    if (game == null || !context.mounted) return;

    final playerNames = {for (final p in players) p.id: p.displayName};
    final controllers = {for (final id in game.participantIds) id: TextEditingController(text: '0')};

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Puntos de la ronda'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: game.participantIds.map((id) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextField(
                  controller: controllers[id],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: playerNames[id] ?? '...'),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final points = <String, int>{};
              for (final id in game.participantIds) {
                points[id] = int.tryParse(controllers[id]!.text.trim()) ?? 0;
              }
              firestore.addRound(widget.gameId, points);
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
