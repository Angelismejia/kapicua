import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../services/firestore_service.dart';
import 'active_game_screen.dart';
import 'help_screen.dart';
import 'history_screen.dart';
import 'new_game_screen.dart';
import 'players_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
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
      body: StreamBuilder<Game?>(
        stream: firestore.watchActiveGame(),
        builder: (context, snapshot) {
          final activeGame = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '¡Bienvenido! 👋',
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kapicua',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  height: 1.1,
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
                    subtitle: Text('Meta: ${activeGame.targetScore} puntos'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActiveGameScreen(gameId: activeGame.id),
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
      ),
    );
  }
}

class _LogoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset('assets/logo_banner.png', height: 160, width: double.infinity, fit: BoxFit.cover),
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
    final background = emphasized ? colorScheme.primary : colorScheme.surfaceContainerLow;
    final foreground = emphasized ? colorScheme.onPrimary : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: CircleAvatar(
            backgroundColor: emphasized
                ? colorScheme.onPrimary
                : colorScheme.primaryContainer,
            child: Icon(
              icon,
              color: emphasized ? colorScheme.primary : colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(label, style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
          trailing: Icon(Icons.chevron_right, color: foreground),
          onTap: enabled ? onTap : null,
          enabled: enabled,
        ),
      ),
    );
  }
}
