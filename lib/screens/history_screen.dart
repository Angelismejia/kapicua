import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/round.dart';
import '../services/firestore_service.dart';
import '../widgets/score_sheet.dart';

const _kPrimaryGreen = Color(0xFF2E6B3F);
const _kTextColor = Color(0xFF2D2D2D);
const _kMutedText = Color(0xFF6B756D);
const _kDarkCard = Color(0xFF1E2620);
const _kDarkText = Color(0xFFEDF2ED);
const _kDarkMuted = Color(0xFFA9B4AA);

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'es');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kDarkCard : Colors.white;
    final textColor = isDark ? _kDarkText : _kTextColor;
    final mutedColor = isDark ? _kDarkMuted : _kMutedText;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: StreamBuilder<List<Game>>(
        stream: firestore.watchFinishedGames(),
        builder: (context, gamesSnapshot) {
          final games = gamesSnapshot.data ?? [];
          if (games.isEmpty) {
            return const Center(
              child: Text('Todavía no hay partidas terminadas.'),
            );
          }
          return StreamBuilder<List<Player>>(
            stream: firestore.watchAllPlayers(),
            builder: (context, playersSnapshot) {
              final players = {
                for (final p in playersSnapshot.data ?? <Player>[])
                  p.id: p.displayName,
              };
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: games.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final game = games[index];
                  final teamAName = game.teamAPlayerIds
                      .map((id) => players[id] ?? '...')
                      .join(' y ');
                  final teamBName = game.teamBPlayerIds
                      .map((id) => players[id] ?? '...')
                      .join(' y ');
                  final teamAWon = game.winner == 'A';

                  return _GameCard(
                    cardColor: cardColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    teamAName: teamAName,
                    teamBName: teamBName,
                    teamAScore: game.teamAScore,
                    teamBScore: game.teamBScore,
                    teamAWon: teamAWon,
                    dateLabel: game.finishedAt != null
                        ? dateFormat.format(game.finishedAt!)
                        : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GameDetailScreen(game: game, players: players),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final String teamAName;
  final String teamBName;
  final int teamAScore;
  final int teamBScore;
  final bool teamAWon;
  final String? dateLabel;
  final VoidCallback onTap;

  const _GameCard({
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.teamAName,
    required this.teamBName,
    required this.teamAScore,
    required this.teamBScore,
    required this.teamAWon,
    required this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dateLabel != null) ...[
                Text(
                  dateLabel!,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  _TeamResult(
                    name: teamAName,
                    score: teamAScore,
                    won: teamAWon,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    alignment: CrossAxisAlignment.start,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'vs',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12),
                    ),
                  ),
                  _TeamResult(
                    name: teamBName,
                    score: teamBScore,
                    won: !teamAWon,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    alignment: CrossAxisAlignment.end,
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

class _TeamResult extends StatelessWidget {
  final String name;
  final int score;
  final bool won;
  final Color textColor;
  final Color mutedColor;
  final CrossAxisAlignment alignment;

  const _TeamResult({
    required this.name,
    required this.score,
    required this.won,
    required this.textColor,
    required this.mutedColor,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final textAlign = alignment == CrossAxisAlignment.end
        ? TextAlign.right
        : TextAlign.left;
    return Expanded(
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment: alignment == CrossAxisAlignment.end
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (won) ...[
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 16,
                  color: _kPrimaryGreen,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  name,
                  textAlign: textAlign,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$score',
            textAlign: textAlign,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: won ? _kPrimaryGreen : mutedColor,
            ),
          ),
        ],
      ),
    );
  }
}

class GameDetailScreen extends StatelessWidget {
  final Game game;
  final Map<String, String> players;

  const GameDetailScreen({
    super.key,
    required this.game,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final teamAName = game.teamAPlayerIds
        .map((id) => players[id] ?? '...')
        .join(' y ');
    final teamBName = game.teamBPlayerIds
        .map((id) => players[id] ?? '...')
        .join(' y ');

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la partida')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<Round>>(
          stream: firestore.watchRounds(game.id),
          builder: (context, snapshot) {
            final rounds = snapshot.data ?? [];
            return Card(
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
                  if (rounds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No se registraron rondas.'),
                    )
                  else
                    ...rounds.map(
                      (round) => IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: ScoreSheetCell(value: round.teamAPoints),
                            ),
                            const VerticalDivider(width: 1, thickness: 1),
                            Expanded(
                              child: ScoreSheetCell(value: round.teamBPoints),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(height: 1, thickness: 2),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: ScoreSheetTotal(value: game.teamAScore),
                        ),
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(
                          child: ScoreSheetTotal(value: game.teamBScore),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
