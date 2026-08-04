import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../domain/entities/guest_session.dart';
import '../services/onboarding_service.dart';
import 'certificados_tab.dart';
import 'home_tab.dart';
import 'players_screen.dart';
import 'rules_screen.dart';
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

  // Tour de bienvenida (solo la primera vez, por dispositivo): recorre
  // Inicio explicando qué es cada cosa, incluyendo cómo jugar una
  // partida, que es lo más importante. La barra de abajo (Estadísticas,
  // Certificados, Reglas, Liga) NO se señala con Showcase a propósito:
  // NavigationBar de Material 3 duplica internamente el widget del
  // ícono para animar el indicador, y usar la misma GlobalKey en dos
  // lugares a la vez rompe todo el recorrido en silencio. En su lugar,
  // al terminar el recorrido de Inicio se muestra un resumen en texto.
  final _tourNotifKey = GlobalKey();
  final _tourSettingsKey = GlobalKey();
  final _tourNewGameKey = GlobalKey();
  final _tourAddPlayerKey = GlobalKey();
  final _tourHistoryKey = GlobalKey();
  final _tourPlayersQuickActionKey = GlobalKey();
  final _onboardingService = OnboardingService();

  // Fundido suave al cambiar de pestaña: sin esto, IndexedStack cambia
  // de pantalla de golpe, sin ninguna transición, lo que se siente
  // brusco/extraño en vez de una app normal.
  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    final isGuest = context.read<GuestSession>().isGuest;
    // API vigente de showcaseview 5.x: a diferencia de versiones
    // anteriores, ya no hace falta envolver el árbol en ShowCaseWidget —
    // ShowcaseView.register() es un registro global, y las GlobalKey que
    // se le pasan a Showcase() ya no se pegan al widget real (por eso
    // key.currentContext no sirve para saber si ya está montado). El
    // paquete se encarga de esperar solo.
    ShowcaseView.register(onFinish: () => _showBottomTabsSummary(isGuest));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = await _onboardingService.hasSeenHomeTour();
      if (seen || !mounted) return;
      ShowcaseView.get().startShowCase([
        _tourNotifKey,
        _tourSettingsKey,
        _tourNewGameKey,
        _tourAddPlayerKey,
        _tourHistoryKey,
        _tourPlayersQuickActionKey,
      ]);
      await _onboardingService.markHomeTourSeen();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    ShowcaseView.get().unregister();
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
      HomeTab(
        onNavigateTab: selectTab,
        tourNotifKey: _tourNotifKey,
        tourSettingsKey: _tourSettingsKey,
        tourNewGameKey: _tourNewGameKey,
        tourAddPlayerKey: _tourAddPlayerKey,
        tourHistoryKey: _tourHistoryKey,
        tourPlayersKey: _tourPlayersQuickActionKey,
      ),
      StatsScreen(key: ValueKey('stats-$_statsVisitKey')),
      if (!isGuest)
        CertificadosTab(key: ValueKey('certificados-$_certificadosVisitKey')),
      if (!isGuest) const RulesScreen(),
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
          if (!isGuest)
            const NavigationDestination(
              icon: Icon(Icons.rule_outlined),
              selectedIcon: Icon(Icons.rule),
              label: 'Reglas',
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

  /// Resumen en texto de la barra de abajo, mostrado al terminar el
  /// recorrido de Inicio (ver comentario arriba de por qué no se señala
  /// con Showcase directamente).
  void _showBottomTabsSummary(bool isGuest) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Un vistazo rápido más'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Abajo en la barra tienes:'),
            const SizedBox(height: 12),
            _tabSummaryRow(
              Icons.emoji_events_outlined,
              'Estadísticas',
              'El ranking de la liga: quién va ganando este mes, '
                  'porcentajes y récords.',
            ),
            if (!isGuest) ...[
              const SizedBox(height: 10),
              _tabSummaryRow(
                Icons.workspace_premium_outlined,
                'Certificados',
                'El campeón (y el subcampeón) de cada mes, con su '
                    'certificado para descargar, imprimir o compartir.',
              ),
              const SizedBox(height: 10),
              _tabSummaryRow(
                Icons.rule_outlined,
                'Reglas',
                'Las reglas de la liga, siempre a la mano.',
              ),
            ],
            const SizedBox(height: 10),
            _tabSummaryRow(
              Icons.groups_outlined,
              'Liga',
              'Todos los jugadores — agrégalos, edítalos o márcalos '
                  'inactivos desde aquí.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  Widget _tabSummaryRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
