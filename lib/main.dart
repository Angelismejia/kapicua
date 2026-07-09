import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/player.dart';
import 'screens/auth_screen.dart';
import 'screens/family_gate_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // En web, la caché local de Firestore viene apagada por defecto: sin
  // ella, cada inicio de sesión espera a la red antes de mostrar nada.
  // Con esto, lo que ya se vio antes aparece al instante mientras se
  // sincroniza en segundo plano.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
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

/// Resuelve si el usuario entra como invitado o debe ver el PIN familiar.
/// Guarda el Future en el estado para no repetir la consulta cada vez que
/// la lista de jugadores se actualiza (lo que antes hacía parpadear la
/// pantalla de carga).
class _GuestOrFamilyGate extends StatefulWidget {
  final String uid;

  const _GuestOrFamilyGate({required this.uid});

  @override
  State<_GuestOrFamilyGate> createState() => _GuestOrFamilyGateState();
}

class _GuestOrFamilyGateState extends State<_GuestOrFamilyGate> {
  late Future<bool> _guestFuture;

  @override
  void initState() {
    super.initState();
    _guestFuture = context.read<FirestoreService>().hasGuestProfile(widget.uid);
  }

  @override
  void didUpdateWidget(covariant _GuestOrFamilyGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _guestFuture = context.read<FirestoreService>().hasGuestProfile(
        widget.uid,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    return FutureBuilder<bool>(
      future: _guestFuture,
      builder: (context, guestSnapshot) {
        if (!guestSnapshot.hasData) {
          return _loadingScaffold();
        }
        if (guestSnapshot.data == true) {
          firestoreService.isGuest = true;
          firestoreService.guestUid = widget.uid;
          return const MainShell();
        }
        return const FamilyGateScreen();
      },
    );
  }
}

/// Busca el jugador vinculado a esta cuenta una sola vez por uid, en vez
/// de volver a consultar cada vez que se reconstruye el widget (algo que
/// puede pasar más de una vez seguida justo al iniciar sesión, si no se
/// memoriza el Future esto reinicia la consulta cada vez y la pantalla
/// se queda pegada esperando sin avanzar nunca).
class _PlayerLookupGate extends StatefulWidget {
  final String uid;

  const _PlayerLookupGate({required this.uid});

  @override
  State<_PlayerLookupGate> createState() => _PlayerLookupGateState();
}

class _PlayerLookupGateState extends State<_PlayerLookupGate> {
  late Future<Player?> _playerFuture;

  @override
  void initState() {
    super.initState();
    _playerFuture = context.read<FirestoreService>().findPlayerByAuthUid(
      widget.uid,
    );
  }

  @override
  void didUpdateWidget(covariant _PlayerLookupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _playerFuture = context.read<FirestoreService>().findPlayerByAuthUid(
        widget.uid,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    return FutureBuilder<Player?>(
      future: _playerFuture,
      builder: (context, playerSnapshot) {
        if (playerSnapshot.connectionState == ConnectionState.waiting) {
          return _loadingScaffold();
        }
        if (playerSnapshot.data != null) {
          firestoreService.isGuest = false;
          return const MainShell();
        }
        return _GuestOrFamilyGate(uid: widget.uid);
      },
    );
  }
}

class KapicuaApp extends StatelessWidget {
  final ThemeController themeController;
  final AuthService authService;

  const KapicuaApp({
    super.key,
    required this.themeController,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ChangeNotifierProvider<AuthService>.value(value: authService),
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

                return _PlayerLookupGate(uid: user.uid);
              },
            ),
          );
        },
      ),
    );
  }
}
