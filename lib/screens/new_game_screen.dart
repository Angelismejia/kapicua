import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../services/firestore_service.dart';
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

  @override
  void dispose() {
    _customTargetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva partida'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Agregar jugador a la liga',
            onPressed: () => showAddPlayerDialog(context, firestore),
          ),
        ],
      ),
      body: StreamBuilder<List<Player>>(
        stream: firestore.watchActivePlayers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = snapshot.data!;
          if (players.isEmpty) {
            return const Center(
              child: Text(
                'Agrega jugadores primero desde la pantalla de Jugadores.',
              ),
            );
          }
          return ListView(
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
                    onSelected: (_) => setState(() => _selectedPreset = null),
                  ),
                ],
              ),
              if (_selectedPreset == null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customTargetController,
                  keyboardType: TextInputType.text,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Meta personalizada',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _TeamPicker(
                label: 'Casa',
                players: players,
                selected: _teamA,
                otherTeam: _teamB,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 20),
              _TeamPicker(
                label: 'Visita',
                players: players,
                selected: _teamB,
                otherTeam: _teamA,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : () => _startGame(firestore),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar'),
      ),
    );
  }

  Future<void> _startGame(FirestoreService firestore) async {
    final target =
        _selectedPreset ?? int.tryParse(_customTargetController.text.trim());
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una meta de puntos válida.')),
      );
      return;
    }
    if (_teamA.isEmpty || _teamB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos 1 jugador por equipo.'),
        ),
      );
      return;
    }
    setState(() => _creating = true);
    final gameId = await firestore.createGame(
      _teamA.toList(),
      _teamB.toList(),
      target,
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ActiveGameScreen(gameId: gameId)),
    );
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
