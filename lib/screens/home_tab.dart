import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'active_game_screen.dart';
import 'help_screen.dart';
import 'history_screen.dart';
import 'new_game_screen.dart';

class HomeTab extends StatefulWidget {
  final void Function(int index) onNavigateTab;

  const HomeTab({super.key, required this.onNavigateTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final PageController _bannerController = PageController();
  int _bannerPage = 0;

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
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Player>>(
      stream: firestore.watchAllPlayers(),
      builder: (context, allPlayersSnap) {
        final allPlayers = allPlayersSnap.data ?? [];

        Player? me;
        for (final p in allPlayers) {
          if (p.authUid == auth.currentUser?.uid) me = p;
        }

        return StreamBuilder<List<Player>>(
          stream: firestore.watchActivePlayers(),
          builder: (context, activePlayersSnap) {
            final activePlayers = activePlayersSnap.data ?? [];

            return StreamBuilder<List<Game>>(
              stream: firestore.watchFinishedGames(),
              builder: (context, gamesSnap) {
                final finishedGames = gamesSnap.data ?? [];

                return StreamBuilder<Game?>(
                  stream: firestore.watchActiveGame(),
                  builder: (context, activeGameSnap) {
                    final activeGame = activeGameSnap.data;

                    return StreamBuilder<List<PlayerStatEntry>>(
                      stream: firestore.watchAllStatEntries(),
                      builder: (context, entriesSnap) {
                        final statEntries = entriesSnap.data ?? [];

                        return SafeArea(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                            children: [
                              _Header(
                                greeting: _greetingPrefix,
                                name: me?.displayName,
                                colorScheme: colorScheme,
                                onNotificationsTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Muy pronto ✨'),
                                    ),
                                  );
                                },
                                onSettingsTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HelpScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _BannerCarousel(
                                controller: _bannerController,
                                currentPage: _bannerPage,
                                onPageChanged: (i) =>
                                    setState(() => _bannerPage = i),
                                onCertificadosTap: () =>
                                    widget.onNavigateTab(2),
                              ),
                              const SizedBox(height: 24),
                              _Dashboard(
                                totalGames: finishedGames.length,
                                totalPlayers: activePlayers.length,
                                allPlayers: allPlayers,
                                statEntries: statEntries,
                              ),
                              const SizedBox(height: 16),
                              if (finishedGames.isNotEmpty)
                                _LastGameCard(
                                  game: finishedGames.first,
                                  players: {
                                    for (final p in allPlayers)
                                      p.id: p.displayName,
                                  },
                                ),
                              if (activeGame != null) ...[
                                const SizedBox(height: 16),
                                _ActionCard(
                                  icon: Icons.play_circle_fill,
                                  title: 'Partida en curso',
                                  subtitle:
                                      'Meta: ${activeGame.targetScore} puntos',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ActiveGameScreen(
                                        gameId: activeGame.id,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              Text(
                                'Menú',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              _ActionCard(
                                icon: Icons.add_circle_outline,
                                title: 'Nueva partida',
                                subtitle: 'Crea y comienza una partida.',
                                enabled: activeGame == null,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NewGameScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ActionCard(
                                icon: Icons.history,
                                title: 'Historial',
                                subtitle: 'Consulta partidas anteriores.',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HistoryScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String greeting;
  final String? name;
  final ColorScheme colorScheme;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;

  const _Header({
    required this.greeting,
    required this.name,
    required this.colorScheme,
    required this.onNotificationsTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (name != null && name!.isNotEmpty) ? name! : null;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                displayName != null
                    ? '👋 $greeting, $displayName'
                    : '👋 $greeting',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              tooltip: 'Notificaciones',
              onPressed: onNotificationsTap,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Configuración y ayuda',
              onPressed: onSettingsTap,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Kapicua',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'AlexBrush',
            fontSize: 40,
            color: colorScheme.primary,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _BannerCarousel extends StatelessWidget {
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onCertificadosTap;

  const _BannerCarousel({
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
    required this.onCertificadosTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: PageView(
              controller: controller,
              onPageChanged: onPageChanged,
              children: [
                _BannerSlide(
                  image: 'assets/logo_banner.jpg',
                  title: 'La mejor forma de jugar dominó',
                  subtitle: 'Registra, compite y gana.',
                  onTap: null,
                  alignment: Alignment.centerLeft,
                ),
                _BannerSlide(
                  image: 'assets/certificado.png',
                  title: 'Certificado de Campeón',
                  subtitle: 'Genera y comparte el reconocimiento del mes.',
                  onTap: onCertificadosTap,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (i) {
            final active = i == currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
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
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  const Color(0xFF0D2818).withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

class _Dashboard extends StatelessWidget {
  final int totalGames;
  final int totalPlayers;
  final List<Player> allPlayers;
  final List<PlayerStatEntry> statEntries;

  const _Dashboard({
    required this.totalGames,
    required this.totalPlayers,
    required this.allPlayers,
    required this.statEntries,
  });

  @override
  Widget build(BuildContext context) {
    final winsById = <String, int>{};
    for (final e in statEntries) {
      if (e.isWin) winsById[e.playerId] = (winsById[e.playerId] ?? 0) + 1;
    }
    String? leaderId;
    var leaderWins = 0;
    winsById.forEach((id, wins) {
      if (wins > leaderWins) {
        leaderWins = wins;
        leaderId = id;
      }
    });
    Player? leader;
    for (final p in allPlayers) {
      if (p.id == leaderId) leader = p;
    }

    final monthlyWinner = _monthlyLeader(statEntries, allPlayers);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _DashboardCard(
          icon: Icons.casino_outlined,
          iconBg: const Color(0xFFE8F5E9),
          value: '$totalGames',
          label: 'Partidas jugadas',
        ),
        _DashboardCard(
          icon: Icons.groups_outlined,
          iconBg: const Color(0xFFE8F5E9),
          value: '$totalPlayers',
          label: 'En la liga',
        ),
        _DashboardCard(
          icon: Icons.military_tech_outlined,
          iconBg: const Color(0xFFE8F5E9),
          value: leader?.displayName ?? '—',
          label: leader != null
              ? '$leaderWins victorias · líder'
              : 'Líder actual',
        ),
        _DashboardCard(
          icon: Icons.local_fire_department_outlined,
          iconBg: const Color(0xFFE8F5E9),
          value: monthlyWinner ?? '—',
          label: 'Ganador del mes',
        ),
      ],
    );
  }

  String? _monthlyLeader(List<PlayerStatEntry> entries, List<Player> players) {
    final now = DateTime.now();
    final winsCount = <String, int>{};
    for (final e in entries) {
      if (!e.isWin) continue;
      if (e.createdAt.year != now.year || e.createdAt.month != now.month) {
        continue;
      }
      winsCount[e.playerId] = (winsCount[e.playerId] ?? 0) + 1;
    }
    if (winsCount.isEmpty) return null;
    String bestId = winsCount.keys.first;
    for (final id in winsCount.keys) {
      if (winsCount[id]! > winsCount[bestId]!) bestId = id;
    }
    for (final p in players) {
      if (p.id == bestId) return p.displayName;
    }
    return null;
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String value;
  final String label;

  const _DashboardCard({
    required this.icon,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: iconBg,
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LastGameCard extends StatelessWidget {
  final Game game;
  final Map<String, String> players;

  const _LastGameCard({required this.game, required this.players});

  String _relativeDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;
    final time = DateFormat('h:mm a', 'es').format(date);
    if (diff == 0) return 'Hoy · $time';
    if (diff == 1) return 'Ayer · $time';
    return '${DateFormat('d MMM', 'es').format(date)} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final winnerName = game.winner == 'A'
        ? game.teamAPlayerIds.map((id) => players[id] ?? '...').join(' y ')
        : game.teamBPlayerIds.map((id) => players[id] ?? '...').join(' y ');
    final winnerScore = game.winner == 'A' ? game.teamAScore : game.teamBScore;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE8F5E9),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Última partida',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _relativeDate(game.finishedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$winnerName ganó con $winnerScore pts',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GameDetailScreen(game: game, players: players),
              ),
            ),
            child: const Text('Ver detalle →'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE8F5E9),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
