import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/guest_session.dart';
import 'certificados_tab.dart';
import 'home_tab.dart';
import 'players_screen.dart';
import 'stats_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  // Cada vez que se sale y se vuelve a entrar a Estadísticas o
  // Certificados, se les da una llave nueva para que empiecen de cero
  // (mes actual) en vez de quedarse pegadas en el mes que se dejó
  // seleccionado la última vez.
  int _statsVisitKey = 0;
  int _certificadosVisitKey = 0;

  // Fundido suave al cambiar de pestaña: sin esto, IndexedStack cambia
  // de pantalla de golpe, sin ninguna transición, lo que se siente
  // brusco/extraño en vez de una app normal.
  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Tocar el ícono de Estadísticas o Certificados siempre reinicia esa
  // pantalla al mes actual, así ya estuvieras en otra pestaña o ya
  // estuvieras parado justo ahí (para cuando se quiere "volver arriba"
  // sin salir primero a otra pestaña).
  void _selectTab(
    int index, {
    required int statsIndex,
    required int certificadosIndex,
  }) {
    setState(() {
      if (index == statsIndex) _statsVisitKey++;
      if (index == certificadosIndex) _certificadosVisitKey++;
      _index = index;
    });
    _fadeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final guestSession = context.read<GuestSession>();
    final isGuest = guestSession.isGuest;
    const statsIndex = 1;
    final certificadosIndex = isGuest ? -1 : 2;

    void selectTab(int index) => _selectTab(
      index,
      statsIndex: statsIndex,
      certificadosIndex: certificadosIndex,
    );

    final tabs = [
      HomeTab(onNavigateTab: selectTab),
      StatsScreen(key: ValueKey('stats-$_statsVisitKey')),
      if (!isGuest)
        CertificadosTab(key: ValueKey('certificados-$_certificadosVisitKey')),
      const PlayersScreen(),
    ];
    if (_index >= tabs.length) _index = tabs.length - 1;

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: selectTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_rounded),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Estadísticas',
          ),
          if (!isGuest)
            const NavigationDestination(
              icon: Icon(Icons.workspace_premium_outlined),
              selectedIcon: Icon(Icons.workspace_premium_rounded),
              label: 'Certificados',
            ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Liga',
          ),
        ],
      ),
    );
  }
}
