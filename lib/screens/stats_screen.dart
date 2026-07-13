import 'dart:convert';
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
import '../utils/monthly_winner.dart';
import '../widgets/month_selector.dart';
import '../widgets/player_stat_history_dialog.dart';

void _showHowItWorksDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('¿Cómo se calcula?'),
      content: const Text(
        'Se calcula por porcentaje de victorias (ganadas ÷ total '
        'jugadas), no por quién tiene más ganadas.\n\n'
        'A partir del día 15 del mes, para poder ir de primero hace '
        'falta haber jugado al menos 40 manos ese mes — si todavía '
        'nadie llega, gana igual quien tenga mejor porcentaje. La misma '
        'regla decide al ganador oficial cuando cierra el mes.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

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

  // Guardados una sola vez en vez de llamarse dentro de build(): así,
  // cambiar de mes o cualquier otro setState de esta pantalla no
  // desconecta y vuelve a conectar los mismos listeners de Firestore.
  late final Stream<List<Player>> _playersStream;
  late final Stream<List<PlayerStatEntry>> _entriesStream;
  late final Stream<List<Game>> _pendingStatsGamesStream;

  @override
  void initState() {
    super.initState();
    final firestore = context.read<FirestoreService>();
    _playersStream = firestore.watchAllPlayers();
    _entriesStream = firestore.watchAllStatEntries();
    _pendingStatsGamesStream = firestore.watchPendingStatsGames();
  }

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
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: '¿Cómo se calcula?',
            onPressed: () => _showHowItWorksDialog(context),
          ),
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
        stream: _playersStream,
        builder: (context, playersSnapshot) {
          // Mientras no ha llegado ni un solo dato todavía (esta pantalla
          // vuelve a empezar de cero cada vez que se visita, para
          // resetear el mes), se muestra cargando en vez de la lista
          // vacía — si no, se ve un parpadeo raro al cambiar de pestaña.
          if (!playersSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = playersSnapshot.data ?? [];
          return StreamBuilder<List<PlayerStatEntry>>(
            stream: _entriesStream,
            builder: (context, entriesSnapshot) {
              if (!entriesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = (entriesSnapshot.data ?? []).where(
                (e) =>
                    e.createdAt.year == _selectedMonth.year &&
                    e.createdAt.month == _selectedMonth.month,
              );

              final statsList = players.where((p) => p.active).map((player) {
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
              }).toList();

              // A partir del día 15 (o si el mes ya terminó), quien no
              // llegue a las 40 manos no puede aparecer arriba en el
              // orden aunque su porcentaje sea mejor que el de alguien
              // que sí llegó.
              final winsMap = {
                for (final s in statsList) s.player.id: s.gamesWon,
              };
              final lossesMap = {
                for (final s in statsList) s.player.id: s.gamesLost,
              };
              final qualifiedIds = qualifiedIdsForRanking(
                winsMap,
                lossesMap,
                _selectedMonth,
              );

              final stats = statsList
                ..sort((a, b) {
                  if (qualifiedIds != null) {
                    final aQualifies = qualifiedIds.contains(a.player.id);
                    final bQualifies = qualifiedIds.contains(b.player.id);
                    if (aQualifies != bQualifies) return aQualifies ? -1 : 1;
                  }
                  final pctCompare = b.winPercentage.compareTo(a.winPercentage);
                  if (pctCompare != 0) return pctCompare;
                  return b.gamesWon.compareTo(a.gamesWon);
                });

              final playerNames = {
                for (final p in players) p.id: p.displayName,
              };

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
                  if (isAdmin)
                    StreamBuilder<List<Game>>(
                      stream: _pendingStatsGamesStream,
                      builder: (context, pendingSnap) {
                        // Si alguno de los dos equipos tiene un jugador
                        // que ya quedó inactivo, no se sugiere — no debe
                        // aparecer nada de un inactivo en Estadísticas.
                        final activeIds = players
                            .where((p) => p.active)
                            .map((p) => p.id)
                            .toSet();
                        final pending = (pendingSnap.data ?? [])
                            .where(
                              (g) => [
                                ...g.teamAPlayerIds,
                                ...g.teamBPlayerIds,
                              ].every(activeIds.contains),
                            )
                            .toList();
                        if (pending.isEmpty) return const SizedBox.shrink();
                        return Column(
                          children: [
                            for (final game in pending)
                              _PendingStatsCard(
                                game: game,
                                playerNames: playerNames,
                                onAdd: () => firestore.applyGameStats(game),
                                onIgnore: () =>
                                    firestore.ignoreGameStats(game.id),
                              ),
                          ],
                        );
                      },
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
                  const SizedBox(height: 8),
                  Text(
                    'Toca el nombre de un jugador para ver su historial'
                    '${isAdmin ? ' y agregar ganadas o perdidas' : ''}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
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

  late final Stream<List<Player>> _playersStream;
  late final Stream<List<Game>> _gamesStream;

  @override
  void initState() {
    super.initState();
    _playersStream = widget.firestore.watchAllPlayers();
    _gamesStream = widget.firestore.watchFinishedGames();
  }

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
        stream: _playersStream,
        builder: (context, playersSnapshot) {
          if (!playersSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = playersSnapshot.data ?? [];
          return StreamBuilder<List<Game>>(
            stream: _gamesStream,
            builder: (context, gamesSnapshot) {
              if (!gamesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final games = gamesSnapshot.data ?? [];

              final stats =
                  players.where((p) => p.active).map((player) {
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

const _kStatsPrimaryGreen = Color(0xFF2E6B3F);
const _kStatsDarkCard = Color(0xFF1E2620);
const _kStatsLightText = Color(0xFF2D2D2D);
const _kStatsDarkText = Color(0xFFEDF2ED);
const _kStatsLightMuted = Color(0xFF6B756D);
const _kStatsDarkMuted = Color(0xFFA9B4AA);
const _kStatsLightGreenBg = Color(0xFFEAF6EB);
const _kStatsDarkGreenBg = Color(0xFF203A28);

/// Aviso para que el admin confirme (o ignore) sumar a Estadísticas el
/// resultado de una partida ya jugada, en vez de tener que escribirlo
/// a mano — la app ya sabe quién ganó y quién perdió.
class _PendingStatsCard extends StatelessWidget {
  final Game game;
  final Map<String, String> playerNames;
  final VoidCallback onAdd;
  final VoidCallback onIgnore;

  const _PendingStatsCard({
    required this.game,
    required this.playerNames,
    required this.onAdd,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final winners = game.winner == 'A'
        ? game.teamAPlayerIds
        : game.teamBPlayerIds;
    final losers = game.winner == 'A'
        ? game.teamBPlayerIds
        : game.teamAPlayerIds;
    final winnerNames = winners
        .map((id) => playerNames[id] ?? '...')
        .join(' y ');
    final loserNames = losers.map((id) => playerNames[id] ?? '...').join(' y ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _kStatsDarkGreenBg : _kStatsLightGreenBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$winnerNames ganaron y $loserNames perdieron. '
            '¿Agregar a estadísticas?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
              color: isDark ? _kStatsDarkText : _kStatsLightText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onIgnore,
                  child: const Text('Ignorar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kStatsPrimaryGreen,
                  ),
                  onPressed: onAdd,
                  child: const Text('Agregar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
              backgroundImage: stats.player.photoBase64 != null
                  ? MemoryImage(base64Decode(stats.player.photoBase64!))
                  : null,
              child: stats.player.photoBase64 == null
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        color: _kStatsPrimaryGreen,
                      ),
                    )
                  : null,
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
