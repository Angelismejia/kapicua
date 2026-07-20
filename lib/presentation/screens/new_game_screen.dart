import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/player.dart';
import '../../domain/repositories/game_repository.dart';
import '../../domain/repositories/player_repository.dart';
import '../widgets/add_player_dialog.dart';
import 'active_game_screen.dart';

const _targetPresets = [100, 150, 200, 300, 500];

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  final Set<String> _teamA = {};
  final Set<String> _teamB = {};
  int? _selectedPreset = 200;
  final _customTargetController = TextEditingController();
  bool _creating = false;
  // Para jugar suelto sin tener que agregar a nadie primero: los
  // equipos quedan como "Casa"/"Visita" (renombrables luego desde el
  // anotador) y la partida no queda ligada a ningún jugador ni
  // estadística.
  bool _quickMode = false;

  @override
  void dispose() {
    _customTargetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = context.read<PlayerRepository>();
    final games = context.read<GameRepository>();

    return StreamBuilder<List<Player>>(
      stream: players.watchActivePlayers(),
      builder: (context, snapshot) {
        final playerList = snapshot.data ?? [];
        // Sin nadie agregado todavía, no tiene caso ofrecer el
        // interruptor: se juega rápido sí o sí.
        final quickMode = _quickMode || playerList.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nueva partida'),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_alt_1),
                tooltip: 'Agregar jugador a la liga',
                onPressed: () => showAddPlayerDialog(context, players),
              ),
            ],
          ),
          body: !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Meta de puntos',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final preset in _targetPresets)
                          ChoiceChip(
                            label: Text('$preset'),
                            selected: _selectedPreset == preset,
                            onSelected: (_) =>
                                setState(() => _selectedPreset = preset),
                          ),
                        ChoiceChip(
                          label: const Text('Personalizado'),
                          selected: _selectedPreset == null,
                          onSelected: (_) =>
                              setState(() => _selectedPreset = null),
                        ),
                      ],
                    ),
                    if (_selectedPreset == null) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customTargetController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Meta personalizada',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (playerList.isNotEmpty)
                      Card(
                        child: SwitchListTile(
                          title: const Text('Jugar rápido sin agregar nombres'),
                          subtitle: const Text(
                            'Equipos "Casa" y "Visita" genéricos, sin ligar la '
                            'partida a ningún jugador.',
                          ),
                          value: quickMode,
                          onChanged: (value) =>
                              setState(() => _quickMode = value),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (quickMode)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            playerList.isEmpty
                                ? 'Vas a jugar entre "Casa" y "Visita". Puedes '
                                      'renombrarlos luego desde el anotador, o '
                                      'agregar jugadores primero con el ícono de '
                                      'arriba si quieres llevar sus nombres.'
                                : 'Vas a jugar entre "Casa" y "Visita", sin '
                                      'ligar la partida a ningún jugador. '
                                      'Puedes renombrarlos luego desde el '
                                      'anotador.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else ...[
                      _TeamPicker(
                        label: 'Casa',
                        players: playerList,
                        selected: _teamA,
                        otherTeam: _teamB,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 20),
                      _TeamPicker(
                        label: 'Visita',
                        players: playerList,
                        selected: _teamB,
                        otherTeam: _teamA,
                        onChanged: () => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _creating
                ? null
                : () => _startGame(games, isQuickMode: quickMode),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar'),
          ),
        );
      },
    );
  }

  Future<void> _startGame(
    GameRepository games, {
    required bool isQuickMode,
  }) async {
    final target =
        _selectedPreset ?? int.tryParse(_customTargetController.text.trim());
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una meta de puntos válida.')),
      );
      return;
    }
    if (!isQuickMode && (_teamA.isEmpty || _teamB.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos 1 jugador por equipo.'),
        ),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final gameId = await games.createGame(
        isQuickMode ? const [] : _teamA.toList(),
        isQuickMode ? const [] : _teamB.toList(),
        target,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ActiveGameScreen(gameId: gameId)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la partida: $e')),
      );
    }
  }
}

class _TeamPicker extends StatelessWidget {
  final String label;
  final List<Player> players;
  final Set<String> selected;
  final Set<String> otherTeam;
  final VoidCallback onChanged;

  const _TeamPicker({
    required this.label,
    required this.players,
    required this.selected,
    required this.otherTeam,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$label (${selected.length}/2)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final player in players)
              CheckboxListTile(
                dense: true,
                title: Text(player.displayName),
                value: selected.contains(player.id),
                onChanged: otherTeam.contains(player.id)
                    ? null
                    : (checked) {
                        if (checked == true) {
                          if (selected.length >= 2) return;
                          selected.add(player.id);
                        } else {
                          selected.remove(player.id);
                        }
                        onChanged();
                      },
              ),
          ],
        ),
      ),
    );
  }
}
