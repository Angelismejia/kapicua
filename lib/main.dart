import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
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

                return PlayerLookupGate(uid: user.uid);
              },
            ),
          );
        },
      ),
    );
  }
}
