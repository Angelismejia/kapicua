import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../models/player_stats.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/month_selector.dart';
import '../widgets/player_stat_history_dialog.dart';

Future<void> _shareStatsImage(GlobalKey repaintKey, String monthLabel) async {
  final boundary =
      repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.5);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  await SharePlus.instance.share(
    ShareParams(
      text: 'Estadísticas de $monthLabel en Kapicua',
      files: [
        XFile.fromData(
          bytes,
          name: 'estadisticas_kapicua.png',
          mimeType: 'image/png',
        ),
      ],
    ),
  );
}

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
  final _shareKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final monthLabel = DateFormat('MMMM yyyy', 'es').format(_selectedMonth);
      await _shareStatsImage(_shareKey, monthLabel);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo compartir: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    if (firestore.isGuest) {
      return _GuestStatsBody(firestore: firestore);
    }

    final isAdmin = context.watch<AuthService>().isAdmin;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            tooltip: 'Compartir estadísticas',
            onPressed: _sharing ? null : _share,
          ),
        ],
      ),
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
                  }).toList()..sort((a, b) {
                    final pctCompare = b.winPercentage.compareTo(
                      a.winPercentage,
                    );
                    if (pctCompare != 0) return pctCompare;
                    return b.gamesWon.compareTo(a.gamesWon);
                  });

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _StatsHeaderAccent(),
                  const SizedBox(height: 12),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: MonthSelector(
                      month: _selectedMonth,
                      onChanged: (m) => setState(() => _selectedMonth = m),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Toca el nombre de un jugador para ver su historial'
                    '${isAdmin ? ' y agregar ganadas o perdidas' : ''}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      color: Color(0xFF666666),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RepaintBoundary(
                    key: _shareKey,
                    child: _StatsList(
                      stats: stats,
                      isAdmin: isAdmin,
                      firestore: firestore,
                      forMonth: _selectedMonth,
                    ),
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

class _GuestStatsBody extends StatefulWidget {
  final FirestoreService firestore;

  const _GuestStatsBody({required this.firestore});

  @override
  State<_GuestStatsBody> createState() => _GuestStatsBodyState();
}

class _GuestStatsBodyState extends State<_GuestStatsBody> {
  final _shareKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final monthLabel = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
      await _shareStatsImage(_shareKey, monthLabel);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo compartir: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = widget.firestore;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            tooltip: 'Compartir estadísticas',
            onPressed: _sharing ? null : _share,
          ),
        ],
      ),
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
                  }).toList()..sort((a, b) {
                    final pctCompare = b.winPercentage.compareTo(
                      a.winPercentage,
                    );
                    if (pctCompare != 0) return pctCompare;
                    return b.gamesWon.compareTo(a.gamesWon);
                  });

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _StatsHeaderAccent(),
                  const SizedBox(height: 12),
                  RepaintBoundary(
                    key: _shareKey,
                    child: _StatsList(
                      stats: stats,
                      isAdmin: false,
                      firestore: firestore,
                      forMonth: DateTime.now(),
                    ),
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

/// Adorno del encabezado: una línea verde fina a cada lado con un
/// trofeo dentro de un círculo, a modo de separador elegante y
/// minimalista entre el título y el selector de mes.
class _StatsHeaderAccent extends StatelessWidget {
  const _StatsHeaderAccent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const green = Color(0xFF2E7D32);

    Widget line() => Container(
      height: 2,
      decoration: BoxDecoration(
        color: green,
        borderRadius: BorderRadius.circular(1),
      ),
    );

    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.55,
        child: Row(
          children: [
            Expanded(child: line()),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? _kStatsDarkCard : Colors.white,
                border: Border.all(color: green, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: green,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: line()),
          ],
        ),
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
  final DateTime forMonth;

  const _StatsList({
    required this.stats,
    required this.isAdmin,
    required this.firestore,
    required this.forMonth,
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
                forMonth,
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
