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
      appBar: AppBar(
        title: const Text('Partida en curso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Cancelar partida',
            onPressed: () => _confirmCancel(context, firestore),
          ),
        ],
      ),
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

              final teamAName = game.teamAPlayerIds
                  .map((id) => players[id] ?? '...')
                  .join(' y ');
              final teamBName = game.teamBPlayerIds
                  .map((id) => players[id] ?? '...')
                  .join(' y ');

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Center(
                      child: Text(
                        'Meta: ${game.targetScore} puntos',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ScoreSheetHeader(
                                      label: 'Casa',
                                      playerNames: teamAName,
                                    ),
                                  ),
                                  const VerticalDivider(width: 1, thickness: 1),
                                  Expanded(
                                    child: _ScoreSheetHeader(
                                      label: 'Visita',
                                      playerNames: teamBName,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, thickness: 1),
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
                                  return ListView.builder(
                                    itemCount: rounds.length,
                                    itemBuilder: (context, index) {
                                      final round = rounds[index];
                                      return IntrinsicHeight(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _ScoreSheetCell(
                                                value: round.teamAPoints,
                                              ),
                                            ),
                                            const VerticalDivider(
                                              width: 1,
                                              thickness: 1,
                                            ),
                                            Expanded(
                                              child: _ScoreSheetCell(
                                                value: round.teamBPoints,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const Divider(height: 1, thickness: 2),
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ScoreSheetTotal(
                                      value: game.teamAScore,
                                    ),
                                  ),
                                  const VerticalDivider(width: 1, thickness: 1),
                                  Expanded(
                                    child: _ScoreSheetTotal(
                                      value: game.teamBScore,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
    final pointsController = TextEditingController();

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
                TextField(
                  controller: pointsController,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Puntos'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final preset in _pointPresets)
                      ActionChip(
                        label: Text('$preset'),
                        onPressed: () =>
                            setState(() => pointsController.text = '$preset'),
                      ),
                  ],
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
                final points = int.tryParse(pointsController.text.trim()) ?? 0;
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

  void _confirmCancel(BuildContext context, FirestoreService firestore) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar partida'),
        content: const Text(
          '¿Seguro que quieres cancelar esta partida? Se borrarán las rondas '
          'anotadas y podrás iniciar una nueva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              await firestore.cancelGame(widget.gameId);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }
}

class _ScoreSheetHeader extends StatelessWidget {
  final String label;
  final String playerNames;

  const _ScoreSheetHeader({required this.label, required this.playerNames});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            playerNames,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ScoreSheetCell extends StatelessWidget {
  final int value;

  const _ScoreSheetCell({required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text('$value', style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class _ScoreSheetTotal extends StatelessWidget {
  final int value;

  const _ScoreSheetTotal({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
