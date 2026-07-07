import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game.dart';
import '../services/firestore_service.dart';
import 'active_game_screen.dart';
import 'certificados_tab.dart';
import 'home_tab.dart';
import 'new_game_screen.dart';
import 'players_screen.dart';
import 'stats_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    final tabs = [
      HomeTab(onNavigateTab: _goToTab),
      const StatsScreen(),
      const CertificadosTab(),
      const PlayersScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      floatingActionButton: _index == 0
          ? StreamBuilder<Game?>(
              stream: firestore.watchActiveGame(),
              builder: (context, snapshot) {
                final activeGame = snapshot.data;
                return FloatingActionButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => activeGame != null
                          ? ActiveGameScreen(gameId: activeGame.id)
                          : const NewGameScreen(),
                    ),
                  ),
                  child: const Icon(Icons.add, size: 30),
                );
              },
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium),
            label: 'Certificados',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Liga',
          ),
        ],
      ),
    );
  }
}
