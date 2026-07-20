import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/firebase_auth_repository.dart';
import 'data/repositories/firestore_admin_repository.dart';
import 'data/repositories/firestore_game_repository.dart';
import 'data/repositories/firestore_guest_repository.dart';
import 'data/repositories/firestore_monthly_override_repository.dart';
import 'data/repositories/firestore_player_repository.dart';
import 'data/repositories/firestore_stats_repository.dart';
import 'domain/entities/app_user.dart';
import 'domain/entities/guest_session.dart';
import 'domain/repositories/admin_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/game_repository.dart';
import 'domain/repositories/guest_repository.dart';
import 'domain/repositories/monthly_override_repository.dart';
import 'domain/repositories/player_repository.dart';
import 'domain/repositories/stats_repository.dart';
import 'domain/usecases/delete_player_permanently_usecase.dart';
import 'domain/usecases/game_usecases.dart';
import 'domain/usecases/merge_players_usecase.dart';
import 'firebase_options.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/controllers/theme_controller.dart';
import 'presentation/screens/auth_gate.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/main_shell.dart';
import 'presentation/services/page_reload/reload.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es');

  final themeController = ThemeController();
  await themeController.load();

  // Se arman aquí (una sola vez, antes de runApp) todos los
  // repositorios y casos de uso, en vez de dentro del árbol de
  // widgets, para que sea explícito qué implementación concreta usa
  // cada interfaz — este es el único archivo que conoce Firebase.
  final db = FirebaseFirestore.instance;
  final guestSession = GuestSession();
  final authRepository = FirebaseAuthRepository();
  final playerRepository = FirestorePlayerRepository(db, guestSession);
  final statsRepository = FirestoreStatsRepository(db, guestSession);
  final gameRepository = FirestoreGameRepository(db, guestSession);
  final adminRepository = FirestoreAdminRepository(db);
  final monthlyOverrideRepository = FirestoreMonthlyOverrideRepository(db);
  final guestRepository = FirestoreGuestRepository(db);
  final authController = AuthController(authRepository, adminRepository);

  runApp(
    MultiProvider(
      providers: [
        Provider<GuestSession>.value(value: guestSession),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<PlayerRepository>.value(value: playerRepository),
        Provider<StatsRepository>.value(value: statsRepository),
        Provider<GameRepository>.value(value: gameRepository),
        Provider<AdminRepository>.value(value: adminRepository),
        Provider<MonthlyOverrideRepository>.value(
          value: monthlyOverrideRepository,
        ),
        Provider<GuestRepository>.value(value: guestRepository),
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        Provider<MergePlayersUseCase>(
          create: (_) => MergePlayersUseCase(playerRepository),
        ),
        Provider<DeletePlayerPermanentlyUseCase>(
          create: (_) => DeletePlayerPermanentlyUseCase(playerRepository),
        ),
        Provider<ApplyGameStatsUseCase>(
          create: (_) => ApplyGameStatsUseCase(gameRepository),
        ),
        Provider<AddRoundUseCase>(
          create: (_) => AddRoundUseCase(gameRepository),
        ),
        Provider<UpdateRoundUseCase>(
          create: (_) => UpdateRoundUseCase(gameRepository),
        ),
        Provider<DeleteRoundUseCase>(
          create: (_) => DeleteRoundUseCase(gameRepository),
        ),
      ],
      child: const KapicuaApp(),
    ),
  );
}

Widget _loadingScaffold() {
  return const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Un momento...'),
        ],
      ),
    ),
  );
}

class KapicuaApp extends StatefulWidget {
  const KapicuaApp({super.key});

  @override
  State<KapicuaApp> createState() => _KapicuaAppState();
}

class _KapicuaAppState extends State<KapicuaApp> with WidgetsBindingObserver {
  bool _reconnecting = false;

  // Se guarda una sola vez (no en cada build) para no resuscribirse al
  // stream cada vez que cambia el tema u otro Provider de arriba avisa.
  late final Stream<AppUser?> _authStateChanges;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authStateChanges = context.read<AuthRepository>().authStateChanges();
    _armStuckAuthWatchdog();
  }

  // En iOS Safari (sobre todo abriendo la app desde el ícono en la
  // pantalla de inicio después de tenerla cerrada un rato) a veces la
  // conexión de IndexedDB que usa Firebase Auth para revisar la sesión
  // guardada se queda trabada y "authStateChanges" nunca llega a avisar
  // nada, dejando la pantalla pegada en "Cargando..." para siempre. Cerrar
  // y volver a abrir la solucionaba porque eso crea una conexión nueva;
  // esto hace lo mismo automáticamente si tarda demasiado.
  void _armStuckAuthWatchdog() {
    if (!kIsWeb) return;
    _authStateChanges.first
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            if (shouldAutoReloadOnce()) reloadPage();
            return null;
          },
        )
        .catchError((_) => null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cuando el celular se bloquea o se cambia de app y se vuelve, la
    // conexión en tiempo real con Firebase a veces se queda "dormida" y no
    // se reconecta sola (más en datos móviles) — se ve como que se queda
    // pegado en "Cargando..." o dice que no hay conexión aunque sí la haya.
    // Forzar apagar y prender la red de Firestore la hace reconectar de
    // una vez, sin tener que salir y volver a entrar a la app.
    if (state == AppLifecycleState.resumed && !_reconnecting) {
      _reconnecting = true;
      FirebaseFirestore.instance
          .disableNetwork()
          .then((_) => FirebaseFirestore.instance.enableNetwork())
          .whenComplete(() => _reconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, controller, _) {
        return MaterialApp(
          title: 'Kapicua',
          themeMode: controller.themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          builder: (context, child) {
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ClipRect(child: child),
                ),
              ),
            );
          },
          home: StreamBuilder<AppUser?>(
            stream: _authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _loadingScaffold();
              }
              final user = snapshot.data;
              final guestSession = context.read<GuestSession>();

              if (user == null) {
                // Sin sesión: nunca debe quedar leyendo un espacio de
                // invitado viejo (ej. si cerró sesión después de "Jugar
                // sin cuenta"), o la pantalla de registro real vería la
                // lista de jugadores vacía en vez de la de la familia.
                guestSession.isGuest = false;
                guestSession.guestUid = null;
                return const AuthScreen();
              }

              // "Jugar sin cuenta": anónimo, va directo a su propio
              // espacio de invitado, sin PIN ni preguntas.
              if (user.isAnonymous) {
                guestSession.isGuest = true;
                guestSession.guestUid = user.uid;
                return const MainShell();
              }

              // Cuenta real (correo y contraseña): asegura que no quede
              // pegado en un espacio de invitado viejo de una sesión
              // anónima anterior.
              guestSession.isGuest = false;
              guestSession.guestUid = null;

              return PlayerLookupGate(uid: user.uid);
            },
          ),
        );
      },
    );
  }
}
