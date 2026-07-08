import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/round.dart';
import '../services/firestore_service.dart';
import '../widgets/score_sheet.dart';
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Meta: ${game.targetScore} puntos',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _showRoundDialog(context, firestore),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Agregar ronda'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toca una ronda para editarla o borrarla.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ScoreSheetHeader(
                                      label: 'Casa',
                                      playerNames: teamAName,
                                    ),
                                  ),
                                  const VerticalDivider(width: 1, thickness: 1),
                                  Expanded(
                                    child: ScoreSheetHeader(
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
                                      return GestureDetector(
                                        onTap: () => _showRoundOptions(
                                          context,
                                          firestore,
                                          round,
                                        ),
                                        child: IntrinsicHeight(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: ScoreSheetCell(
                                                  value: round.teamAPoints,
                                                ),
                                              ),
                                              const VerticalDivider(
                                                width: 1,
                                                thickness: 1,
                                              ),
                                              Expanded(
                                                child: ScoreSheetCell(
                                                  value: round.teamBPoints,
                                                ),
                                              ),
                                            ],
                                          ),
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
                                    child: ScoreSheetTotal(
                                      value: game.teamAScore,
                                    ),
                                  ),
                                  const VerticalDivider(width: 1, thickness: 1),
                                  Expanded(
                                    child: ScoreSheetTotal(
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
    );
  }

  void _showRoundOptions(
    BuildContext context,
    FirestoreService firestore,
    Round round,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.scoreboard_outlined),
              title: Text('Ronda: ${round.teamAPoints} - ${round.teamBPoints}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar puntos'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar ronda'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (action == 'edit') {
      _showEditRoundDialog(context, firestore, round);
    } else if (action == 'delete') {
      _confirmDeleteRound(context, firestore, round);
    }
  }

  void _confirmDeleteRound(
    BuildContext context,
    FirestoreService firestore,
    Round round,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar ronda'),
        content: Text(
          '¿Borrar la ronda con ${round.teamAPoints} - ${round.teamBPoints}? '
          'Los totales se recalculan solos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              firestore.deleteRound(widget.gameId, round.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showEditRoundDialog(
    BuildContext context,
    FirestoreService firestore,
    Round round,
  ) {
    var winningTeam = round.teamAPoints >= round.teamBPoints ? 'A' : 'B';
    final initialPoints = winningTeam == 'A'
        ? round.teamAPoints
        : round.teamBPoints;
    final pointsController = TextEditingController(text: '$initialPoints');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Editar ronda'),
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
                  keyboardType: TextInputType.number,
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
                firestore.updateRound(
                  widget.gameId,
                  round.id,
                  teamAPoints,
                  teamBPoints,
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
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
                  keyboardType: TextInputType.number,
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
