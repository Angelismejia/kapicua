import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ShowCaseWidget/of/startShowCase están deprecados en showcaseview 5.x a
// favor de ShowcaseView.register()/get() (se quitan recién en 6.0.0);
// siguen funcionando igual mientras tanto, se ignora a propósito.
// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:showcaseview/showcaseview.dart';

import '../../domain/entities/guest_session.dart';
import '../services/onboarding_service.dart';
import '../widgets/showcase_helper.dart';
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
  // Inicio y luego la barra de abajo, explicando qué es cada cosa —
  // incluyendo cómo jugar una partida, que es lo más importante.
  final _tourNotifKey = GlobalKey();
  final _tourSettingsKey = GlobalKey();
  final _tourNewGameKey = GlobalKey();
  final _tourAddPlayerKey = GlobalKey();
  final _tourHistoryKey = GlobalKey();
  final _tourPlayersQuickActionKey = GlobalKey();
  final _tourStatsTabKey = GlobalKey();
  final _tourCertificadosTabKey = GlobalKey();
  final _tourRulesTabKey = GlobalKey();
  final _tourLigaTabKey = GlobalKey();
  final _onboardingService = OnboardingService();
  bool _tourTriggered = false;

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

    return ShowCaseWidget(
      builder: (showcaseContext) {
        if (!_tourTriggered) {
          _tourTriggered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final seen = await _onboardingService.hasSeenHomeTour();
            if (seen || !mounted) return;
            // Inicio empieza mostrando su propio círculo de carga
            // mientras llegan los datos de Firestore — hay que esperar a
            // que ya esté el contenido real (los botones que se van a
            // señalar) antes de arrancar el recorrido, si no, no
            // encuentra dónde apuntar y no aparece nada.
            var attempts = 0;
            while (_tourNotifKey.currentContext == null && attempts < 1200) {
              await Future.delayed(const Duration(milliseconds: 100));
              attempts++;
              if (!mounted) return;
            }
            if (_tourNotifKey.currentContext == null) return;
            ShowCaseWidget.of(showcaseContext).startShowCase([
              _tourNotifKey,
              _tourSettingsKey,
              _tourNewGameKey,
              _tourAddPlayerKey,
              _tourHistoryKey,
              _tourPlayersQuickActionKey,
              _tourStatsTabKey,
              if (!isGuest) _tourCertificadosTabKey,
              if (!isGuest) _tourRulesTabKey,
              _tourLigaTabKey,
            ]);
            await _onboardingService.markHomeTourSeen();
          });
        }
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
              NavigationDestination(
                icon: maybeShowcase(
                  key: _tourStatsTabKey,
                  title: 'Estadísticas',
                  description:
                      'El ranking de la liga: quién va ganando este mes, '
                      'porcentajes y récords de cada jugador.',
                  child: const Icon(Icons.emoji_events_outlined),
                ),
                selectedIcon: const Icon(Icons.emoji_events_rounded),
                label: 'Estadísticas',
              ),
              if (!isGuest)
                NavigationDestination(
                  icon: maybeShowcase(
                    key: _tourCertificadosTabKey,
                    title: 'Certificados',
                    description:
                        'El campeón (y el subcampeón) de cada mes, con su '
                        'certificado listo para descargar, imprimir o '
                        'compartir.',
                    child: const Icon(Icons.workspace_premium_outlined),
                  ),
                  selectedIcon: const Icon(Icons.workspace_premium_rounded),
                  label: 'Certificados',
                ),
              if (!isGuest)
                NavigationDestination(
                  icon: maybeShowcase(
                    key: _tourRulesTabKey,
                    title: 'Reglas',
                    description: 'Las reglas de la liga, siempre a la mano.',
                    child: const Icon(Icons.rule_outlined),
                  ),
                  selectedIcon: const Icon(Icons.rule),
                  label: 'Reglas',
                ),
              NavigationDestination(
                icon: maybeShowcase(
                  key: _tourLigaTabKey,
                  title: 'Liga',
                  description:
                      'Todos los jugadores de la liga — agrégalos, '
                      'edítalos o márcalos inactivos desde aquí.',
                  child: const Icon(Icons.groups_outlined),
                ),
                selectedIcon: const Icon(Icons.groups_rounded),
                label: 'Liga',
              ),
            ],
          ),
        );
      },
    );
  }
}
