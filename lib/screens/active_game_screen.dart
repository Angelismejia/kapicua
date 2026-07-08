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
const _kPrimaryGreen = Color(0xFF2E6B3F);

/// Un campo de puntos por equipo, lado a lado, cada uno con sus propios
/// atajos rápidos. En dominó ambos equipos pueden anotar puntos en la
/// misma ronda (ej. cierre con fichas en ambas manos), así que se
/// escriben los dos valores por separado en vez de elegir un único
/// "ganador de la ronda".
Widget _teamPointsFields(
  TextEditingController teamAController,
  TextEditingController teamBController,
  StateSetter setState,
) {
  Widget column(TextEditingController controller, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final preset in _pointPresets)
                  ActionChip(
                    label: Text('$preset'),
                    onPressed: () =>
                        setState(() => controller.text = '$preset'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      column(teamAController, 'Casa'),
      column(teamBController, 'Visita'),
    ],
  );
}

/// Encabezado por equipo, al estilo de las apps clásicas de anotar
/// dominó: nombre del equipo y jugadores a la izquierda, y el botón "+"
/// grande a la derecha (donde antes iba el puntaje) para sumar una
/// ronda. El puntaje total se ve abajo, no aquí.
class _TeamHeaderPill extends StatelessWidget {
  final String label;
  final String playerNames;
  final VoidCallback onAdd;

  const _TeamHeaderPill({
    required this.label,
    required this.playerNames,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _kPrimaryGreen,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _kPrimaryGreen.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  if (playerNames.isNotEmpty)
                    Text(
                      playerNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.white.withValues(alpha: 0.2),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAdd,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marcador de total al pie de la pantalla: puntaje actual sobre la
/// meta (ej. "85/200") con una barrita de progreso, para que se vea de
/// un vistazo qué tan cerca está cada equipo de ganar.
class _TeamTotalReadout extends StatelessWidget {
  final String label;
  final int score;
  final int targetScore;

  const _TeamTotalReadout({
    required this.label,
    required this.score,
    required this.targetScore,
  });

  @override
  Widget build(BuildContext context) {
    final progress = targetScore <= 0
        ? 0.0
        : (score / targetScore).clamp(0.0, 1.0);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.6,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$score',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                    color: _kPrimaryGreen,
                  ),
                ),
                TextSpan(
                  text: '/$targetScore',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: _kPrimaryGreen.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(_kPrimaryGreen),
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo rápido para sumar una ronda desde el botón "+" de la pastilla
/// de un equipo: teclado numérico propio (más rápido en el celular que
/// el teclado del sistema) y dos formas de confirmar — "Para ambos" si
/// los dos equipos anotaron el mismo puntaje esa ronda (ej. tranca), u
/// "OK" si solo anotó el equipo cuyo "+" se tocó.
class _QuickAddRoundDialog extends StatefulWidget {
  final String teamLabel;
  final void Function(int value, bool bothTeams) onSubmit;
  final ValueChanged<String> onRename;

  const _QuickAddRoundDialog({
    required this.teamLabel,
    required this.onSubmit,
    required this.onRename,
  });

  @override
  State<_QuickAddRoundDialog> createState() => _QuickAddRoundDialogState();
}

class _QuickAddRoundDialogState extends State<_QuickAddRoundDialog> {
  String _digits = '';
  late String _teamLabel = widget.teamLabel;

  void _tapDigit(String d) {
    if (_digits.length >= 3) return;
    setState(() => _digits += d);
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _submit(bool bothTeams) {
    widget.onSubmit(int.tryParse(_digits) ?? 0, bothTeams);
    Navigator.pop(context);
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _teamLabel);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nombre del equipo'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (newLabel == null || newLabel.isEmpty || !mounted) return;
    setState(() => _teamLabel = newLabel);
    widget.onRename(newLabel);
  }

  @override
  Widget build(BuildContext context) {
    final display = _digits.isEmpty ? '0' : _digits;

    Widget keypadButton(String label, {VoidCallback? onTap, Widget? child}) {
      return Expanded(
        child: AspectRatio(
          aspectRatio: 1.5,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Material(
              color: Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Center(
                  child:
                      child ??
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _teamLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: _kPrimaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _rename,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: _kPrimaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                display,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 48,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _submit(true),
                      child: const Text(
                        'Para ambos',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPrimaryGreen,
                      ),
                      onPressed: () => _submit(false),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Row(
                  children: [
                    for (final d in row)
                      keypadButton(d, onTap: () => _tapDigit(d)),
                  ],
                ),
              Row(
                children: [
                  keypadButton('', onTap: null),
                  keypadButton('0', onTap: () => _tapDigit('0')),
                  keypadButton(
                    '',
                    onTap: _backspace,
                    child: const Icon(Icons.backspace_outlined, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

              final teamAName = game.teamAPlayerIds
                  .map((id) => players[id] ?? '...')
                  .join(' y ');
              final teamBName = game.teamBPlayerIds
                  .map((id) => players[id] ?? '...')
                  .join(' y ');
              final teamALabel = game.teamALabel ?? 'Casa';
              final teamBLabel = game.teamBLabel ?? 'Visita';

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _TeamHeaderPill(
                          label: teamALabel,
                          playerNames: teamAName,
                          onAdd: () => _showQuickAddDialog(
                            context,
                            firestore,
                            'A',
                            teamALabel,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _TeamHeaderPill(
                          label: teamBLabel,
                          playerNames: teamBName,
                          onAdd: () => _showQuickAddDialog(
                            context,
                            firestore,
                            'B',
                            teamBLabel,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Toca una ronda para editarla, o la X para borrarla.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
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
                                return InkWell(
                                  onTap: () => _showEditRoundDialog(
                                    context,
                                    firestore,
                                    round,
                                  ),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          child: Text(
                                            '${index + 1}',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
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
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            color: Colors.red,
                                            size: 18,
                                          ),
                                          tooltip: 'Eliminar ronda',
                                          onPressed: () => _confirmDeleteRound(
                                            context,
                                            firestore,
                                            round,
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
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _TeamTotalReadout(
                          label: teamALabel,
                          score: game.teamAScore,
                          targetScore: game.targetScore,
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(
                              color: Colors.red,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _confirmCancel(context, firestore),
                          child: const Text(
                            'REINICIAR',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        _TeamTotalReadout(
                          label: teamBLabel,
                          score: game.teamBScore,
                          targetScore: game.targetScore,
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
    final teamAController = TextEditingController(text: '${round.teamAPoints}');
    final teamBController = TextEditingController(text: '${round.teamBPoints}');

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
                const Text(
                  'Puntos de cada equipo en esta ronda',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
                const SizedBox(height: 12),
                _teamPointsFields(teamAController, teamBController, setState),
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
                final teamAPoints =
                    int.tryParse(teamAController.text.trim()) ?? 0;
                final teamBPoints =
                    int.tryParse(teamBController.text.trim()) ?? 0;
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

  void _showQuickAddDialog(
    BuildContext context,
    FirestoreService firestore,
    String team,
    String teamLabel,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => _QuickAddRoundDialog(
        teamLabel: teamLabel,
        onSubmit: (value, bothTeams) {
          final teamAPoints = bothTeams ? value : (team == 'A' ? value : 0);
          final teamBPoints = bothTeams ? value : (team == 'B' ? value : 0);
          firestore.addRound(widget.gameId, teamAPoints, teamBPoints);
        },
        onRename: (newLabel) =>
            firestore.renameGameTeam(widget.gameId, team, newLabel),
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
