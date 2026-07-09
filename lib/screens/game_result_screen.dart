import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../services/firestore_service.dart';
import 'active_game_screen.dart';
import 'main_shell.dart';

const _kPrimaryGreen = Color(0xFF2E6B3F);

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
              final teamAWon = game.winner == 'A';

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 64,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¡$winnerName ganaron la partida!',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: _ResultTeam(
                                  label: game.teamALabel ?? 'Casa',
                                  playerNames: teamAName,
                                  score: game.teamAScore,
                                  won: teamAWon,
                                ),
                              ),
                              const VerticalDivider(width: 1, thickness: 1),
                              Expanded(
                                child: _ResultTeam(
                                  label: game.teamBLabel ?? 'Visita',
                                  playerNames: teamBName,
                                  score: game.teamBScore,
                                  won: !teamAWon,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('¿Fue un error? Reanudar partida'),
                        onPressed: () async {
                          await firestore.reopenGame(gameId);
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ActiveGameScreen(gameId: gameId),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _kPrimaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
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

class _ResultTeam extends StatelessWidget {
  final String label;
  final String playerNames;
  final int score;
  final bool won;

  const _ResultTeam({
    required this.label,
    required this.playerNames,
    required this.score,
    required this.won,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: won ? _kPrimaryGreen.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (won)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Icon(
                Icons.emoji_events_rounded,
                color: _kPrimaryGreen,
                size: 20,
              ),
            ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            playerNames,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 32,
              color: won ? _kPrimaryGreen : null,
            ),
          ),
        ],
      ),
    );
  }
}
