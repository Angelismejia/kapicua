import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/monthly_winner.dart';
import '../widgets/add_player_dialog.dart';
import 'active_game_screen.dart';
import 'help_screen.dart';
import 'history_screen.dart';
import 'new_game_screen.dart';
import 'profile_screen.dart';

const _kPrimaryGreen = Color(0xFF2E6B3F);
const _kSecondaryGreen = Color(0xFF5C9E61);
const _kLightGreen = Color(0xFFEAF6EB);
const _kTextColor = Color(0xFF2D2D2D);
const _kMutedText = Color(0xFF6B756D);

const _kDarkCard = Color(0xFF1E2620);
const _kDarkText = Color(0xFFEDF2ED);
const _kDarkMuted = Color(0xFFA9B4AA);
const _kDarkLightGreen = Color(0xFF203A28);

/// Chiste personal para cuando tu última ganada/perdida registrada fue
/// una perdida — se elige uno al azar cada vez que se abren las
/// notificaciones, para que no se sienta repetitivo. "{name}" se
/// reemplaza por el nombre del jugador.
const _kRoastMessages = [
  '{name}, hoy viniste fue a calentar la silla.',
  'El que pierda hoy invita la próxima Presidente — creo que te tocó a ti.',
  'Hoy las fichas no cooperaron contigo, {name}.',
  'Ni el café te despertó pa\' jugar hoy.',
  'Hasta los buenos jugadores tienen sus días malos.',
  'Respira... y pide revancha.',
  'Hoy tocó aprender humildad. La próxima vienes más preparado.',
  'El dominó da muchas vueltas — hoy no fue tu día, ya vendrá otro.',
];

/// Colores que cambian según el tema, para que las tarjetas de Inicio se
/// vean bien tanto en modo claro como oscuro (antes eran fijos y en modo
/// oscuro las tarjetas blancas quedaban chocando contra el fondo oscuro).
extension _HomeColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;
  Color get cardColor => _isDark ? _kDarkCard : Colors.white;
  Color get homeTextColor => _isDark ? _kDarkText : _kTextColor;
  Color get homeMutedColor => _isDark ? _kDarkMuted : _kMutedText;
  Color get lightGreenBg => _isDark ? _kDarkLightGreen : _kLightGreen;
}

class HomeTab extends StatefulWidget {
  final void Function(int index) onNavigateTab;

  const HomeTab({super.key, required this.onNavigateTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final PageController _bannerController = PageController();
  int _bannerPage = 0;
  double _opacity = 0;

  // Guardados una sola vez en vez de llamarse dentro de build(): así, el
  // fade-in inicial, el swipe del carrusel o cualquier otro setState de
  // esta pantalla no desconecta y vuelve a conectar los mismos listeners
  // de Firestore (antes cada rebuild creaba 3 listeners nuevos).
  late final Stream<List<Player>> _playersStream;
  late final Stream<List<Game>> _activeGamesStream;
  late final Stream<List<PlayerStatEntry>> _statEntriesStream;

  @override
  void initState() {
    super.initState();
    final firestore = context.read<FirestoreService>();
    _playersStream = firestore.watchAllPlayers();
    _activeGamesStream = firestore.watchActiveGames();
    _statEntriesStream = firestore.watchAllStatEntries();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  String get _greetingPrefix {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final auth = context.watch<AuthService>();
    final isGuest = firestore.isGuest;
    final ligaIndex = isGuest ? 2 : 3;
    const certificadosIndex = 2;

    return StreamBuilder<List<Player>>(
      stream: _playersStream,
      builder: (context, allPlayersSnap) {
        // Mientras no ha llegado ni un solo dato todavía (justo después
        // de iniciar sesión), se muestra cargando en vez de dibujar la
        // pantalla con todo en cero — si no, por un instante se ve como
        // si se hubiera perdido todo, y da un susto sin necesidad.
        if (!allPlayersSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allPlayers = allPlayersSnap.data ?? [];
        // En vez de un segundo listener a Firestore solo para los
        // activos, se filtran los mismos jugadores ya cargados arriba
        // (menos listeners = pantalla de Inicio más liviana y rápida).
        final activePlayers = allPlayers.where((p) => p.active).toList();

        Player? me;
        for (final p in allPlayers) {
          if (p.authUid == auth.currentUser?.uid) me = p;
        }

        return StreamBuilder<List<Game>>(
          stream: _activeGamesStream,
          builder: (context, activeGamesSnap) {
            final activeGames = activeGamesSnap.data ?? [];
            final playerNames = {
              for (final p in allPlayers) p.id: p.displayName,
            };

            return StreamBuilder<List<PlayerStatEntry>>(
              stream: _statEntriesStream,
              builder: (context, entriesSnap) {
                final statEntries = entriesSnap.data ?? [];
                // Quien entra sin cuenta juega suelto, sin liga ni
                // competencia real con nadie más — no tiene sentido
                // hablarle de "quién va ganando" ni de hitos de la liga.
                final championMessages = isGuest
                    ? <String>[]
                    : _championMessages(statEntries, activePlayers, me, auth);
                final hasNotifications = _buildNotifications(
                  me,
                  activePlayers,
                  statEntries,
                  auth,
                  isGuest,
                ).isNotEmpty;

                return SafeArea(
                  child: AnimatedOpacity(
                    opacity: _opacity,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      children: [
                        _Header(
                          greeting: _greetingPrefix,
                          name: me?.displayName,
                          photoBase64: me?.photoBase64,
                          hasNotifications: hasNotifications,
                          onNotificationsTap: () => _showNotifications(
                            context,
                            me,
                            activePlayers,
                            statEntries,
                            auth,
                            isGuest,
                          ),
                          onSettingsTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HelpScreen(),
                            ),
                          ),
                          onProfileTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(player: me),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _KapicuaLogo(),
                        const SizedBox(height: 28),
                        _BannerCarousel(
                          controller: _bannerController,
                          currentPage: _bannerPage,
                          onPageChanged: (i) => setState(() => _bannerPage = i),
                          isGuest: isGuest,
                          onCertificadosTap: isGuest
                              ? null
                              : () => widget.onNavigateTab(certificadosIndex),
                        ),
                        const SizedBox(height: 24),
                        _PlayersCard(
                          totalPlayers: activePlayers.length,
                          onAddPlayer: () =>
                              showAddPlayerDialog(context, firestore),
                        ),
                        if (!isGuest) ...[
                          const SizedBox(height: 20),
                          _ChampionCarousel(messages: championMessages),
                        ],
                        for (final game in activeGames) ...[
                          const SizedBox(height: 20),
                          _ActiveGameCard(
                            targetScore: game.targetScore,
                            teamAName: game.teamAPlayerIds.isEmpty
                                ? (game.teamALabel ?? 'Casa')
                                : game.teamAPlayerIds
                                      .map((id) => playerNames[id] ?? '...')
                                      .join(' y '),
                            teamBName: game.teamBPlayerIds.isEmpty
                                ? (game.teamBLabel ?? 'Visita')
                                : game.teamBPlayerIds
                                      .map((id) => playerNames[id] ?? '...')
                                      .join(' y '),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ActiveGameScreen(gameId: game.id),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                        Text(
                          'Acciones rápidas',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: context.homeTextColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _QuickActionsGrid(
                          onAddPlayer: () =>
                              showAddPlayerDialog(context, firestore),
                          onNewGame: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NewGameScreen(),
                            ),
                          ),
                          onHistory: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          ),
                          onPlayers: () => widget.onNavigateTab(ligaIndex),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Racha de victorias seguidas de un jugador: cuenta las ganadas más
  /// recientes hasta la primera perdida, empezando por el historial
  /// ordenado de más nuevo a más viejo.
  int _currentWinStreak(String playerId, List<PlayerStatEntry> entries) {
    final sorted = entries.where((e) => e.playerId == playerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    var streak = 0;
    for (final e in sorted) {
      if (!e.isWin) break;
      streak++;
    }
    return streak;
  }

  /// Racha de perdidas seguidas de un jugador (lo que en las mesas de
  /// dominó dominicanas se conoce como "una lisa"): igual que la racha
  /// de ganadas, pero al revés.
  int _currentLossStreak(String playerId, List<PlayerStatEntry> entries) {
    final sorted = entries.where((e) => e.playerId == playerId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    var streak = 0;
    for (final e in sorted) {
      if (e.isWin) break;
      streak++;
    }
    return streak;
  }

  List<_Notification> _buildNotifications(
    Player? me,
    List<Player> allPlayers,
    List<PlayerStatEntry> statEntries,
    AuthService auth,
    bool isGuest,
  ) {
    final notifications = <_Notification>[];
    final now = DateTime.now();

    // Quien entra sin cuenta juega suelto, sin liga ni competencia real
    // con nadie más — todo lo de "quién va ganando" o campeón del mes
    // solo tiene sentido para la familia registrada.
    if (!isGuest) {
      // Campeón del mes anterior: se avisa durante los primeros días del
      // mes nuevo, mientras sigue siendo noticia reciente.
      if (now.day <= 5) {
        final previousMonth = DateTime(now.year, now.month - 1);
        final lastMonthWinner = computeMonthlyWinner(
          statEntries,
          allPlayers,
          previousMonth,
        );
        if (lastMonthWinner != null) {
          final label = DateFormat('MMMM', 'es').format(previousMonth);
          notifications.add(
            _Notification(
              icon: Icons.emoji_events_rounded,
              message:
                  '${lastMonthWinner.player.displayName} se llevó $label '
                  'con ${lastMonthWinner.wins} victorias. ¡A celebrar!',
            ),
          );
        }
      }

      // Competencia reñida: si los dos que más ganan este mes están a lo
      // sumo a 1 victoria de diferencia, se avisa. Solo cuenta a
      // jugadores activos (si alguien quedó inactivo, no debe seguir
      // apareciendo como si todavía estuviera compitiendo).
      final activeIds = allPlayers.map((p) => p.id).toSet();
      final currentMonthWins = <String, int>{};
      for (final e in statEntries) {
        if (!e.isWin) continue;
        if (e.createdAt.year != now.year || e.createdAt.month != now.month) {
          continue;
        }
        if (!activeIds.contains(e.playerId)) continue;
        currentMonthWins[e.playerId] = (currentMonthWins[e.playerId] ?? 0) + 1;
      }
      final ranked = currentMonthWins.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (ranked.length >= 2 &&
          ranked[1].value > 0 &&
          ranked[0].value - ranked[1].value <= 1) {
        final nameA = allPlayers
            .firstWhere((p) => p.id == ranked[0].key)
            .displayName;
        final nameB = allPlayers
            .firstWhere((p) => p.id == ranked[1].key)
            .displayName;
        notifications.add(
          _Notification(
            icon: Icons.bolt_rounded,
            message: '¡Reñida competencia este mes entre $nameA y $nameB!',
          ),
        );
      }
    }

    // Ánimo: si todavía no eres quien más gana este mes, un empujoncito.
    final currentMonthWinner = computeMonthlyWinner(
      statEntries,
      allPlayers,
      DateTime(now.year, now.month),
    );
    if (me != null &&
        (currentMonthWinner == null || currentMonthWinner.player.id != me.id)) {
      notifications.add(
        const _Notification(
          icon: Icons.rocket_launch_rounded,
          message: 'Todavía vas a tiempo de ponerte de primero este mes.',
        ),
      );
    }

    if (me != null) {
      final myEntries = statEntries.where((e) => e.playerId == me.id);
      final myWins = myEntries.where((e) => e.isWin).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (myWins.isNotEmpty) {
        final lastWin = myWins.first;
        final daysSince = DateTime.now().difference(lastWin.createdAt).inDays;
        if (daysSince <= 7) {
          notifications.add(
            const _Notification(
              icon: Icons.emoji_events_rounded,
              message: '¡Ganaste una partida esta semana! Sigue así.',
            ),
          );
        } else {
          notifications.add(
            _Notification(
              icon: Icons.emoji_events_rounded,
              message:
                  'Ya llevas ${myWins.length} victoria'
                  '${myWins.length == 1 ? '' : 's'} en la liga.',
            ),
          );
        }
      }

      // Si lo último que se le registró fue una perdida reciente, un
      // chistecito personal en vez de puro ánimo serio.
      final myRecent = myEntries.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (myRecent.isNotEmpty && !myRecent.first.isWin) {
        final daysSinceLoss = now.difference(myRecent.first.createdAt).inDays;
        if (daysSinceLoss <= 2) {
          final pick =
              _kRoastMessages[now.millisecondsSinceEpoch %
                      _kRoastMessages.length]
                  .replaceAll('{name}', me.displayName);
          notifications.add(
            _Notification(icon: Icons.mood_bad_rounded, message: pick),
          );
        }
      }
    }

    final creationTime = auth.currentUser?.metadata.creationTime;
    if (creationTime != null) {
      final daysSince = DateTime.now().difference(creationTime).inDays;
      if (daysSince < 1) {
        notifications.add(
          const _Notification(
            icon: Icons.waving_hand_rounded,
            message: '¡Bienvenido a Kapicua! Que gane el mejor.',
          ),
        );
      } else if (daysSince >= 30) {
        notifications.add(
          _Notification(
            icon: Icons.celebration_rounded,
            message: '¡Llevas $daysSince días jugando en Kapicua!',
          ),
        );
      }
    }

    // Chismes de la liga: le llegan a todos, no solo al jugador vinculado.
    // No aplica a quien entra sin cuenta (no hay "liga" de la que
    // chismear).
    if (!isGuest) {
      for (final player in allPlayers) {
        final streak = _currentLossStreak(player.id, statEntries);
        if (streak >= 3) {
          notifications.add(
            _Notification(
              icon: Icons.trending_down_rounded,
              message:
                  '¡${player.displayName} va en una lisa de $streak '
                  'partidas seguidas!',
            ),
          );
        }
      }
    }

    return notifications;
  }

  void _showNotifications(
    BuildContext context,
    Player? me,
    List<Player> allPlayers,
    List<PlayerStatEntry> statEntries,
    AuthService auth,
    bool isGuest,
  ) {
    final notifications = _buildNotifications(
      me,
      allPlayers,
      statEntries,
      auth,
      isGuest,
    );

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notificaciones',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: context.homeTextColor,
                ),
              ),
              const SizedBox(height: 16),
              if (notifications.isEmpty)
                Text(
                  'No tienes notificaciones nuevas por ahora.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: context.homeMutedColor,
                  ),
                )
              else
                for (final n in notifications)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: _kPrimaryGreen.withValues(
                            alpha: 0.12,
                          ),
                          child: Icon(n.icon, size: 18, color: _kPrimaryGreen),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              n.message,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13.5,
                                color: context.homeTextColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  /// Arma los mensajes del carrusel de Inicio: el campeón del mes pasado
  /// (solo los primeros 7 días del mes nuevo, para celebrarlo mientras es
  /// noticia reciente), quién tiene el mejor porcentaje este mes, un
  /// mensaje personalizado, la racha de quien ve la app, comparaciones
  /// con el líder, un hito de la liga y el aniversario de la cuenta.
  List<String> _championMessages(
    List<PlayerStatEntry> entries,
    List<Player> players,
    Player? me,
    AuthService auth,
  ) {
    final messages = <String>[];
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);

    if (now.day <= 7) {
      final lastMonth = DateTime(now.year, now.month - 1);
      final lastWinner = computeMonthlyWinner(entries, players, lastMonth);
      if (lastWinner != null) {
        messages.add(
          'El mes pasado se lo llevó ${lastWinner.player.displayName}',
        );
      }
    }

    final leader = computeMonthlyPercentageLeader(entries, players, thisMonth);
    if (leader != null) {
      final isMeLeading = me != null && leader.player.id == me.id;
      messages.add(
        isMeLeading
            ? '¡Vas de primero este mes! No aflojes'
            : '${leader.player.displayName} va de primero este mes. '
                  'Dale que el próximo puedes ser tú.',
      );
    }

    // Racha personal, comparación directa y diferencia chica con el
    // líder: solo tienen sentido para quien tiene cuenta vinculada.
    if (me != null) {
      final myStreak = _currentWinStreak(me.id, entries);
      if (myStreak >= 2) {
        messages.add(
          'Llevas $myStreak ganadas seguidas, tu mejor racha del mes.',
        );
      }

      if (leader != null && leader.player.id != me.id) {
        final winsThisMonth = <String, int>{};
        for (final e in entries) {
          if (!e.isWin) continue;
          if (e.createdAt.year != now.year || e.createdAt.month != now.month) {
            continue;
          }
          winsThisMonth[e.playerId] = (winsThisMonth[e.playerId] ?? 0) + 1;
        }
        final myWins = winsThisMonth[me.id] ?? 0;
        final gap = leader.wins - myWins;
        if (gap == 0) {
          messages.add(
            'Vas empatado con ${leader.player.displayName} este mes.',
          );
        } else if (gap >= 1 && gap <= 3) {
          messages.add(
            'Solo te faltan $gap ganada${gap == 1 ? '' : 's'} para '
            'alcanzar a ${leader.player.displayName}.',
          );
        }
      }
    }

    // Hito de la liga: total de ganadas/perdidas registradas alguna vez.
    if (entries.length >= 10) {
      messages.add('Ya van ${entries.length} partidas jugadas en total.');
    }

    // Aniversario de la cuenta (cada mes cumplido, en el mismo día).
    final creationTime = auth.currentUser?.metadata.creationTime;
    if (creationTime != null) {
      var totalMonths =
          (now.year - creationTime.year) * 12 +
          (now.month - creationTime.month);
      if (now.day < creationTime.day) totalMonths--;
      if (totalMonths >= 1 && now.day == creationTime.day) {
        if (totalMonths % 12 == 0) {
          final years = totalMonths ~/ 12;
          messages.add(
            'Hoy se cumplen $years año${years == 1 ? '' : 's'} jugando '
            'en Kapicua.',
          );
        } else {
          messages.add(
            'Hoy se cumplen $totalMonths mes${totalMonths == 1 ? '' : 'es'} '
            'jugando en Kapicua.',
          );
        }
      }
    }

    return messages;
  }
}

class _Header extends StatelessWidget {
  final String greeting;
  final String? name;
  final String? photoBase64;
  final bool hasNotifications;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onProfileTap;

  const _Header({
    required this.greeting,
    required this.name,
    required this.photoBase64,
    required this.hasNotifications,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (name != null && name!.isNotEmpty) ? name! : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: context.homeTextColor,
                  ),
                  tooltip: 'Notificaciones',
                  onPressed: onNotificationsTap,
                ),
                if (hasNotifications)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.cardColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.settings_outlined, color: context.homeTextColor),
              tooltip: 'Configuración y ayuda',
              onPressed: onSettingsTap,
            ),
            const SizedBox(width: 4),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: onProfileTap,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: _kPrimaryGreen.withValues(alpha: 0.15),
                backgroundImage: photoBase64 != null
                    ? MemoryImage(base64Decode(photoBase64!))
                    : null,
                child: photoBase64 == null
                    ? Text(
                        displayName != null && displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _kPrimaryGreen,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
        Text(
          displayName != null ? '$greeting, $displayName' : greeting,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: 22,
            color: context.homeTextColor,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Lista para jugar dominó.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: context.homeMutedColor,
          ),
        ),
      ],
    );
  }
}

/// El nombre "Kapicua" como elemento visual principal debajo del saludo:
/// ocupa la mitad del ancho de la pantalla, centrado, y nunca se ve más
/// pequeño que el texto del saludo (se ajusta con FittedBox).
class _KapicuaLogo extends StatelessWidget {
  const _KapicuaLogo();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SizedBox(
            width: constraints.maxWidth * 0.52,
            child: const FittedBox(
              fit: BoxFit.contain,
              child: Text(
                'Kapicua',
                style: TextStyle(
                  fontFamily: 'AlexBrush',
                  fontSize: 64,
                  color: _kPrimaryGreen,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BannerCarousel extends StatelessWidget {
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onCertificadosTap;
  final bool isGuest;

  const _BannerCarousel({
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
    required this.onCertificadosTap,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context) {
    // Quien entra sin cuenta no tiene certificados (esa sección ni le
    // aparece), así que no tiene sentido promocionarla en el banner.
    final slides = [
      _BannerSlide(
        image: 'assets/logo_banner.jpg',
        title: 'La mejor forma de jugar dominó',
        subtitle: 'Registra, compite y gana.',
        onTap: null,
        alignment: Alignment.centerLeft,
      ),
      if (!isGuest)
        _BannerSlide(
          image: 'assets/certificado.png',
          title: 'Certificado de Campeón',
          subtitle: 'Genera y comparte el reconocimiento del mes.',
          onTap: onCertificadosTap,
        ),
    ];

    return Column(
      children: [
        AspectRatio(
          // La imagen del banner (dominó/Presidente/logo) es panorámica,
          // no 16:9 — usamos su proporción real para no recortarla.
          aspectRatio: 900 / 410,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: PageView(
                controller: controller,
                onPageChanged: onPageChanged,
                children: slides,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (slides.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) {
              final active = i == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? _kPrimaryGreen
                      : _kPrimaryGreen.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _BannerSlide extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Alignment alignment;

  const _BannerSlide({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(image, fit: BoxFit.cover, alignment: alignment),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayersCard extends StatelessWidget {
  final int totalPlayers;
  final VoidCallback onAddPlayer;

  const _PlayersCard({required this.totalPlayers, required this.onAddPlayer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.groups_rounded,
                      size: 16,
                      color: _kPrimaryGreen,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LIGA',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        color: _kPrimaryGreen.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalPlayers',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 36,
                    color: context.homeTextColor,
                    height: 1,
                  ),
                ),
                Text(
                  'Jugadores registrados',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: context.homeMutedColor,
                  ),
                ),
              ],
            ),
          ),
          _ScaleOnTap(
            onTap: onAddPlayer,
            // Se ajusta al contenido (en vez de un ancho fijo) para que
            // no se coma el espacio de la columna de la izquierda en
            // teléfonos angostos.
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _kPrimaryGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Agregar',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recuadro destacado en Inicio que rota solo entre varios mensajes
/// (campeón del mes pasado, quién tiene mejor porcentaje, mensaje
/// personalizado) cada pocos segundos, en vez de mostrar un solo dato
/// fijo.
class _ChampionCarousel extends StatefulWidget {
  final List<String> messages;

  const _ChampionCarousel({required this.messages});

  @override
  State<_ChampionCarousel> createState() => _ChampionCarouselState();
}

class _ChampionCarouselState extends State<_ChampionCarousel> {
  int _index = 0;
  Timer? _timer;
  late List<String> _order = _shuffled(widget.messages);

  List<String> _shuffled(List<String> input) => [...input]..shuffle();

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _ChampionCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo se vuelve a barajar si el contenido realmente cambió (no en
    // cada actualización de Firestore), para no interrumpir la rotación.
    if (widget.messages.join('|') != oldWidget.messages.join('|')) {
      _order = _shuffled(widget.messages);
      _index = 0;
    }
  }

  void _restartTimer() {
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _order.isEmpty) return;
      setState(() => _index = (_index + 1) % _order.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _order.isEmpty
        ? 'Aún sin datos este mes'
        : _order[_index % _order.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.lightGreenBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                text,
                key: ValueKey(text),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: context.homeTextColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.emoji_events_rounded,
            size: 52,
            color: _kSecondaryGreen,
          ),
        ],
      ),
    );
  }
}

class _ActiveGameCard extends StatelessWidget {
  final int targetScore;
  final String teamAName;
  final String teamBName;
  final VoidCallback onTap;

  const _ActiveGameCard({
    required this.targetScore,
    required this.teamAName,
    required this.teamBName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ScaleOnTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: _kPrimaryGreen,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _kPrimaryGreen.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    teamAName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'vs',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    teamBName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Meta: $targetScore puntos',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onAddPlayer;
  final VoidCallback onNewGame;
  final VoidCallback onHistory;
  final VoidCallback onPlayers;

  const _QuickActionsGrid({
    required this.onAddPlayer,
    required this.onNewGame,
    required this.onHistory,
    required this.onPlayers,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 18,
      crossAxisSpacing: 18,
      childAspectRatio: 1.15,
      children: [
        _QuickActionButton(
          icon: Icons.add_circle_outline_rounded,
          label: 'Nueva partida',
          onTap: onNewGame,
        ),
        _QuickActionButton(
          icon: Icons.person_add_alt_1_rounded,
          label: 'Agregar jugador',
          onTap: onAddPlayer,
        ),
        _QuickActionButton(
          icon: Icons.history_rounded,
          label: 'Historial',
          onTap: onHistory,
        ),
        _QuickActionButton(
          icon: Icons.groups_2_rounded,
          label: 'Jugadores',
          onTap: onPlayers,
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ScaleOnTap(
      onTap: onTap,
      child: Material(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 30, color: _kPrimaryGreen),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: context.homeTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Envoltorio reutilizable: reduce ligeramente de tamaño al presionar,
/// para que los botones se sientan táctiles sin exagerar la animación.
class _ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ScaleOnTap({required this.child, required this.onTap});

  @override
  State<_ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<_ScaleOnTap> {
  double _scale = 1;

  void _setScale(double value) {
    if (widget.onTap == null) return;
    setState(() => _scale = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setScale(0.96),
      onTapUp: (_) => _setScale(1),
      onTapCancel: () => _setScale(1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _Notification {
  final IconData icon;
  final String message;

  const _Notification({required this.icon, required this.message});
}
