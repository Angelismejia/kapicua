import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/page_reload/reload.dart';
import 'services/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es');
  final themeController = ThemeController();
  await themeController.load();
  final authService = AuthService();
  runApp(
    KapicuaApp(themeController: themeController, authService: authService),
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
  final ThemeController themeController;
  final AuthService authService;

  const KapicuaApp({
    super.key,
    required this.themeController,
    required this.authService,
  });

  @override
  State<KapicuaApp> createState() => _KapicuaAppState();
}

class _KapicuaAppState extends State<KapicuaApp> with WidgetsBindingObserver {
  bool _reconnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    FirebaseAuth.instance
        .authStateChanges()
        .first
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
    return MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<ThemeController>.value(
          value: widget.themeController,
        ),
        ChangeNotifierProvider<AuthService>.value(value: widget.authService),
      ],
      child: Consumer<ThemeController>(
        builder: (context, controller, _) {
          return MaterialApp(
            title: 'Kapicua',
            themeMode: controller.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E6B3F),
              ),
              useMaterial3: true,
              fontFamily: 'Poppins',
              scaffoldBackgroundColor: const Color(0xFFF6F8F5),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                indicatorColor: const Color(0xFFEAF6EB),
                labelTextStyle: WidgetStateProperty.all(
                  const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E6B3F),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              fontFamily: 'Poppins',
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                labelTextStyle: WidgetStateProperty.all(
                  const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
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
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _loadingScaffold();
                }
                final user = snapshot.data;
                final firestoreService = context.read<FirestoreService>();

                if (user == null) {
                  // Sin sesión: nunca debe quedar leyendo un espacio de
                  // invitado viejo (ej. si cerró sesión después de "Jugar
                  // sin cuenta"), o la pantalla de registro real vería la
                  // lista de jugadores vacía en vez de la de la familia.
                  firestoreService.isGuest = false;
                  firestoreService.guestUid = null;
                  return const AuthScreen();
                }

                // "Jugar sin cuenta": anónimo, va directo a su propio
                // espacio de invitado, sin PIN ni preguntas.
                if (user.isAnonymous) {
                  firestoreService.isGuest = true;
                  firestoreService.guestUid = user.uid;
                  return const MainShell();
                }

                // Cuenta real (correo y contraseña): asegura que no quede
                // pegado en un espacio de invitado viejo de una sesión
                // anónima anterior.
                firestoreService.isGuest = false;
                firestoreService.guestUid = null;

                return PlayerLookupGate(uid: user.uid);
              },
            ),
          );
        },
      ),
    );
  }
}
