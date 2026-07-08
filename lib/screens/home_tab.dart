import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/add_player_dialog.dart';
import 'active_game_screen.dart';
import 'help_screen.dart';
import 'history_screen.dart';
import 'new_game_screen.dart';

const _kPrimaryGreen = Color(0xFF2E6B3F);
const _kSecondaryGreen = Color(0xFF5C9E61);
const _kLightGreen = Color(0xFFEAF6EB);
const _kTextColor = Color(0xFF2D2D2D);
const _kMutedText = Color(0xFF6B756D);

const _kDarkCard = Color(0xFF1E2620);
const _kDarkText = Color(0xFFEDF2ED);
const _kDarkMuted = Color(0xFFA9B4AA);
const _kDarkLightGreen = Color(0xFF203A28);

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

  @override
  void initState() {
    super.initState();
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

            return StreamBuilder<Game?>(
              stream: firestore.watchActiveGame(),
              builder: (context, activeGameSnap) {
                final activeGame = activeGameSnap.data;

                return StreamBuilder<List<PlayerStatEntry>>(
                  stream: firestore.watchAllStatEntries(),
                  builder: (context, entriesSnap) {
                    final statEntries = entriesSnap.data ?? [];
                    final monthlyWinner = _monthlyLeader(
                      statEntries,
                      allPlayers,
                    );

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
                              onNotificationsTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Muy pronto')),
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
                            const _KapicuaLogo(),
                            const SizedBox(height: 28),
                            _BannerCarousel(
                              controller: _bannerController,
                              currentPage: _bannerPage,
                              onPageChanged: (i) =>
                                  setState(() => _bannerPage = i),
                              onCertificadosTap: isGuest
                                  ? null
                                  : () =>
                                        widget.onNavigateTab(certificadosIndex),
                            ),
                            const SizedBox(height: 24),
                            _PlayersCard(
                              totalPlayers: activePlayers.length,
                              onAddPlayer: () =>
                                  showAddPlayerDialog(context, firestore),
                            ),
                            const SizedBox(height: 20),
                            _ChampionCard(championName: monthlyWinner),
                            if (activeGame != null) ...[
                              const SizedBox(height: 20),
                              _ActiveGameCard(
                                targetScore: activeGame.targetScore,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ActiveGameScreen(gameId: activeGame.id),
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
                              activeGame: activeGame,
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
      },
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

class _Header extends StatelessWidget {
  final String greeting;
  final String? name;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;

  const _Header({
    required this.greeting,
    required this.name,
    required this.onNotificationsTap,
    required this.onSettingsTap,
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
            IconButton(
              icon: Icon(
                Icons.notifications_none_rounded,
                color: context.homeTextColor,
              ),
              tooltip: 'Notificaciones',
              onPressed: onNotificationsTap,
            ),
            IconButton(
              icon: Icon(Icons.settings_outlined, color: context.homeTextColor),
              tooltip: 'Configuración y ayuda',
              onPressed: onSettingsTap,
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
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (i) {
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
            child: Container(
              width: 170,
              height: 52,
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

class _ChampionCard extends StatelessWidget {
  final String? championName;

  const _ChampionCard({required this.championName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.lightGreenBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campeón del mes',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kSecondaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  championName ?? 'Aún sin definir',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: context.homeTextColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
  final VoidCallback onTap;

  const _ActiveGameCard({required this.targetScore, required this.onTap});

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
                children: [
                  const Text(
                    'Partida en curso',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
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
  final Game? activeGame;
  final VoidCallback onAddPlayer;
  final VoidCallback onNewGame;
  final VoidCallback onHistory;
  final VoidCallback onPlayers;

  const _QuickActionsGrid({
    required this.activeGame,
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
          enabled: activeGame == null,
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
  final bool enabled;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return _ScaleOnTap(
      onTap: enabled ? onTap : null,
      child: Material(
        color: enabled
            ? context.cardColor
            : context.cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
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
                Icon(
                  icon,
                  size: 30,
                  color: enabled
                      ? _kPrimaryGreen
                      : _kPrimaryGreen.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: enabled
                        ? context.homeTextColor
                        : context.homeMutedColor,
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
