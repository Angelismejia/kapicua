import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../services/device_player_service.dart';
import '../services/firestore_service.dart';
import 'active_game_screen.dart';
import 'help_screen.dart';
import 'history_screen.dart';
import 'new_game_screen.dart';
import 'players_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _offeredWhoAreYou = false;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final devicePlayer = context.watch<DevicePlayerService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración y ayuda',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Player>>(
        stream: firestore.watchActivePlayers(),
        builder: (context, playersSnapshot) {
          final players = playersSnapshot.data ?? [];

          if (!_offeredWhoAreYou &&
              devicePlayer.playerId == null &&
              players.isNotEmpty) {
            _offeredWhoAreYou = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showWhoAreYouDialog(context, devicePlayer, players);
            });
          }

          Player? me;
          for (final p in players) {
            if (p.id == devicePlayer.playerId) me = p;
          }
          final greeting = me != null
              ? '¡Bienvenido, ${me.displayName}! 👋'
              : '¡Bienvenido! 👋';

          return StreamBuilder<Game?>(
            stream: firestore.watchActiveGame(),
            builder: (context, snapshot) {
              final activeGame = snapshot.data;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GestureDetector(
                    onTap: () =>
                        _showWhoAreYouDialog(context, devicePlayer, players),
                    child: Text(
                      greeting,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kapicua',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'AlexBrush',
                      fontSize: 52,
                      color: colorScheme.primary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _LogoBanner(),
                  const SizedBox(height: 20),
                  if (activeGame != null) ...[
                    Card(
                      color: colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.play_circle_fill),
                        title: const Text('Partida en curso'),
                        subtitle: Text(
                          'Meta: ${activeGame.targetScore} puntos',
                        ),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ActiveGameScreen(gameId: activeGame.id),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _MenuButton(
                    icon: Icons.people,
                    label: 'Jugadores',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PlayersScreen()),
                    ),
                  ),
                  _MenuButton(
                    icon: Icons.add_circle,
                    label: 'Nueva partida',
                    enabled: activeGame == null,
                    emphasized: activeGame == null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewGameScreen()),
                    ),
                  ),
                  _MenuButton(
                    icon: Icons.history,
                    label: 'Historial',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  _MenuButton(
                    icon: Icons.emoji_events,
                    label: 'Estadísticas',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StatsScreen()),
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

  void _showWhoAreYouDialog(
    BuildContext context,
    DevicePlayerService devicePlayer,
    List<Player> players,
  ) {
    showDialog(
      context: context,
      barrierDismissible: devicePlayer.playerId != null,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Quién eres?'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: players.length,
            itemBuilder: (context, index) {
              final player = players[index];
              return ListTile(
                title: Text(player.displayName),
                onTap: () {
                  devicePlayer.setPlayer(player.id);
                  Navigator.pop(dialogContext);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ahora no'),
          ),
        ],
      ),
    );
  }
}

class _LogoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 160,
        width: double.infinity,
        color: colorScheme.surfaceContainerLow,
        child: Image.asset('assets/logo_banner.png', fit: BoxFit.contain),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool emphasized;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = emphasized
        ? colorScheme.primary
        : colorScheme.surfaceContainerLow;
    final foreground = emphasized
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: CircleAvatar(
            backgroundColor: emphasized
                ? colorScheme.onPrimary
                : colorScheme.primaryContainer,
            child: Icon(
              icon,
              color: emphasized
                  ? colorScheme.primary
                  : colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
          ),
          trailing: Icon(Icons.chevron_right, color: foreground),
          onTap: enabled ? onTap : null,
          enabled: enabled,
        ),
      ),
    );
  }
}
