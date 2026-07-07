import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/round.dart';
import '../services/firestore_service.dart';
import 'game_result_screen.dart';

const _pointPresets = [25, 50, 75, 100];

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
                MaterialPageRoute(
                  builder: (_) => GameResultScreen(gameId: game.id),
                ),
              );
            });
          }

          return StreamBuilder<List<Player>>(
            stream: firestore.watchAllPlayers(),
            builder: (context, playersSnapshot) {
              final players = {
                for (final p in playersSnapshot.data ?? <Player>[])
                  p.id: p.displayName,
              };

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta: ${game.targetScore} puntos · Ronda ${game.roundCount}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TeamScoreCard(
                            label: 'Casa',
                            playerNames: game.teamAPlayerIds
                                .map((id) => players[id] ?? '...')
                                .join(' y '),
                            score: game.teamAScore,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TeamScoreCard(
                            label: 'Visita',
                            playerNames: game.teamBPlayerIds
                                .map((id) => players[id] ?? '...')
                                .join(' y '),
                            score: game.teamBScore,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Historial',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<List<Round>>(
                        stream: firestore.watchRounds(widget.gameId),
                        builder: (context, roundsSnapshot) {
                          final rounds = roundsSnapshot.data ?? [];
                          if (rounds.isEmpty) {
                            return const Center(
                              child: Text('Todavía no hay rondas.'),
                            );
                          }
                          final reversed = rounds.reversed.toList();
                          return ListView.builder(
                            itemCount: reversed.length,
                            itemBuilder: (context, index) {
                              final round = reversed[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text('${round.roundNumber}'),
                                  ),
                                  title: Text(
                                    'Casa ${round.teamAPoints} — Visita ${round.teamBPoints}',
                                  ),
                                ),
                              );
                            },
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

  void _showRoundDialog(
    BuildContext context,
    FirestoreService firestore,
  ) async {
    final game = await firestore.watchGame(widget.gameId).first;
    if (game == null || !context.mounted) return;

    var winningTeam = 'A';
    int? selectedPreset = 25;
    final customController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('Ronda ${game.roundCount + 1}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¿Quién ganó la ronda?'),
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Casa'),
                  value: 'A',
                  groupValue: winningTeam,
                  onChanged: (v) => setState(() => winningTeam = v!),
                ),
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visita'),
                  value: 'B',
                  groupValue: winningTeam,
                  onChanged: (v) => setState(() => winningTeam = v!),
                ),
                const SizedBox(height: 12),
                const Text('Puntos'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final preset in _pointPresets)
                      ChoiceChip(
                        label: Text('$preset'),
                        selected: selectedPreset == preset,
                        onSelected: (_) =>
                            setState(() => selectedPreset = preset),
                      ),
                    ChoiceChip(
                      label: const Text('Otro'),
                      selected: selectedPreset == null,
                      onSelected: (_) => setState(() => selectedPreset = null),
                    ),
                  ],
                ),
                if (selectedPreset == null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customController,
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Puntos'),
                  ),
                ],
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
                final points =
                    selectedPreset ??
                    int.tryParse(customController.text.trim()) ??
                    0;
                final teamAPoints = winningTeam == 'A' ? points : 0;
                final teamBPoints = winningTeam == 'B' ? points : 0;
                firestore.addRound(widget.gameId, teamAPoints, teamBPoints);
                Navigator.pop(dialogContext);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamScoreCard extends StatelessWidget {
  final String label;
  final String playerNames;
  final int score;

  const _TeamScoreCard({
    required this.label,
    required this.playerNames,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text(
              playerNames,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text('$score', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}
