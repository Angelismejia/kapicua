import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../models/player_stats.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/month_selector.dart';
import '../widgets/player_stat_history_dialog.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    if (firestore.isGuest) {
      return _GuestStatsBody(firestore: firestore);
    }

    final isAdmin = context.watch<AuthService>().isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: StreamBuilder<List<Player>>(
        stream: firestore.watchAllPlayers(),
        builder: (context, playersSnapshot) {
          final players = playersSnapshot.data ?? [];
          return StreamBuilder<List<PlayerStatEntry>>(
            stream: firestore.watchAllStatEntries(),
            builder: (context, entriesSnapshot) {
              final entries = (entriesSnapshot.data ?? []).where(
                (e) =>
                    e.createdAt.year == _selectedMonth.year &&
                    e.createdAt.month == _selectedMonth.month,
              );

              final stats =
                  players.map((player) {
                    var won = 0;
                    var lost = 0;
                    for (final e in entries) {
                      if (e.playerId != player.id) continue;
                      if (e.isWin) {
                        won++;
                      } else {
                        lost++;
                      }
                    }
                    return PlayerStats(
                      player: player,
                      gamesWon: won,
                      gamesLost: lost,
                    );
                  }).toList()..sort(
                    (a, b) => b.winPercentage.compareTo(a.winPercentage),
                  );

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (entriesSnapshot.hasError)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'No se pudieron cargar las estadísticas: '
                          '${entriesSnapshot.error}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  if (!isAdmin)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Sesión actual: ${context.read<AuthService>().currentUser?.email ?? '(sin correo)'} '
                          '— no tiene permiso de administrador, por eso no puedes '
                          'agregar ganadas/perdidas.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  MonthSelector(
                    month: _selectedMonth,
                    onChanged: (m) => setState(() => _selectedMonth = m),
                  ),
                  const SizedBox(height: 12),
                  _StatsList(
                    stats: stats,
                    isAdmin: isAdmin,
                    firestore: firestore,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca el nombre de un jugador para ver su historial'
                    '${isAdmin ? ' y agregar ganadas o perdidas' : ''}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _GuestStatsBody extends StatelessWidget {
  final FirestoreService firestore;

  const _GuestStatsBody({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: StreamBuilder<List<Player>>(
        stream: firestore.watchAllPlayers(),
        builder: (context, playersSnapshot) {
          final players = playersSnapshot.data ?? [];
          return StreamBuilder<List<Game>>(
            stream: firestore.watchFinishedGames(),
            builder: (context, gamesSnapshot) {
              final games = gamesSnapshot.data ?? [];

              final stats =
                  players.map((player) {
                    var won = 0;
                    var lost = 0;
                    for (final g in games) {
                      final inA = g.teamAPlayerIds.contains(player.id);
                      final inB = g.teamBPlayerIds.contains(player.id);
                      if (!inA && !inB) continue;
                      final playerWon =
                          (inA && g.winner == 'A') || (inB && g.winner == 'B');
                      if (playerWon) {
                        won++;
                      } else {
                        lost++;
                      }
                    }
                    return PlayerStats(
                      player: player,
                      gamesWon: won,
                      gamesLost: lost,
                    );
                  }).toList()..sort(
                    (a, b) => b.winPercentage.compareTo(a.winPercentage),
                  );

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _StatsList(
                    stats: stats,
                    isAdmin: false,
                    firestore: firestore,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Calculado automáticamente según tus partidas jugadas.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

const _kStatsPrimaryGreen = Color(0xFF2E6B3F);
const _kStatsDarkCard = Color(0xFF1E2620);
const _kStatsLightText = Color(0xFF2D2D2D);
const _kStatsDarkText = Color(0xFFEDF2ED);
const _kStatsLightMuted = Color(0xFF6B756D);
const _kStatsDarkMuted = Color(0xFFA9B4AA);

/// Reemplaza la tabla anterior (DataTable con scroll horizontal, poco
/// amigable en móvil) por una lista de tarjetas — mismo estilo que Inicio,
/// y se adapta a modo claro/oscuro.
class _StatsList extends StatelessWidget {
  final List<PlayerStats> stats;
  final bool isAdmin;
  final FirestoreService firestore;

  const _StatsList({
    required this.stats,
    required this.isAdmin,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? _kStatsDarkCard : Colors.white;
    final textColor = isDark ? _kStatsDarkText : _kStatsLightText;
    final mutedColor = isDark ? _kStatsDarkMuted : _kStatsLightMuted;

    if (stats.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          'Todavía no hay jugadores en la liga.',
          style: TextStyle(fontFamily: 'Poppins', color: mutedColor),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: mutedColor.withValues(alpha: 0.15),
              ),
            _StatsRow(
              rank: i + 1,
              stats: stats[i],
              isAdmin: isAdmin,
              textColor: textColor,
              mutedColor: mutedColor,
              onTap: () => showPlayerStatHistoryDialog(
                context,
                firestore,
                stats[i].player,
                isAdmin,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int rank;
  final PlayerStats stats;
  final bool isAdmin;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback? onTap;

  const _StatsRow({
    required this.rank,
    required this.stats,
    required this.isAdmin,
    required this.textColor,
    required this.mutedColor,
    this.onTap,
  });

  static const _medalColors = {
    1: Color(0xFFC9A227),
    2: Color(0xFF9AA0A6),
    3: Color(0xFFB08D57),
  };

  @override
  Widget build(BuildContext context) {
    final pct = stats.winPercentage;
    final pctColor = pct >= 50 ? _kStatsPrimaryGreen : mutedColor;
    final displayName = stats.player.displayName;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: rank <= 3
                  ? Icon(
                      Icons.emoji_events_rounded,
                      color: _medalColors[rank],
                      size: 22,
                    )
                  : Text(
                      '$rank',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: mutedColor,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: _kStatsPrimaryGreen.withValues(alpha: 0.12),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color: _kStatsPrimaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: textColor,
                      decoration: TextDecoration.underline,
                      decorationColor: mutedColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${stats.gamesWon} ganadas · ${stats.gamesLost} perdidas',
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: mutedColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: pctColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: pctColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
