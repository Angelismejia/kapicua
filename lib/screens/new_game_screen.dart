import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../services/firestore_service.dart';
import 'active_game_screen.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  final Set<String> _selected = {};
  final _targetController = TextEditingController(text: '200');
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva partida')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Meta de puntos',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Selecciona los participantes:'),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Player>>(
              stream: firestore.watchActivePlayers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final players = snapshot.data!;
                if (players.isEmpty) {
                  return const Center(
                    child: Text('Agrega jugadores primero desde la pantalla de Jugadores.'),
                  );
                }
                return ListView(
                  children: players.map((player) {
                    return CheckboxListTile(
                      title: Text(player.displayName),
                      value: _selected.contains(player.id),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(player.id);
                          } else {
                            _selected.remove(player.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : () => _startGame(firestore),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar'),
      ),
    );
  }

  Future<void> _startGame(FirestoreService firestore) async {
    final target = int.tryParse(_targetController.text.trim());
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una meta de puntos válida.')),
      );
      return;
    }
    if (_selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos 2 participantes.')),
      );
      return;
    }
    setState(() => _creating = true);
    final gameId = await firestore.createGame(_selected.toList(), target);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ActiveGameScreen(gameId: gameId)),
    );
  }
}
