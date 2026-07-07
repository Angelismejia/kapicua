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
  await initializeDateFormatting('es');
  final themeController = ThemeController();
  await themeController.load();
  final authService = AuthService();
  runApp(
    KapicuaApp(themeController: themeController, authService: authService),
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
                seedColor: const Color(0xFF2E7D32),
              ),
              useMaterial3: true,
              fontFamily: 'Poppins',
              scaffoldBackgroundColor: const Color(0xFFF7F8F7),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E7D32),
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
                  borderRadius: BorderRadius.circular(20),
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
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final user = snapshot.data;
                if (user == null) return const AuthScreen();

                final firestoreService = context.read<FirestoreService>();

                // "Jugar sin cuenta": anónimo, va directo a su propio
                // espacio de invitado, sin PIN ni preguntas.
                if (user.isAnonymous) {
                  firestoreService.isGuest = true;
                  firestoreService.guestUid = user.uid;
                  return const MainShell();
                }

                return StreamBuilder<List<Player>>(
                  stream: firestoreService.watchAllPlayers(),
                  builder: (context, playersSnapshot) {
                    if (!playersSnapshot.hasData) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final hasLinkedPlayer = playersSnapshot.data!.any(
                      (p) => p.authUid == user.uid,
                    );
                    if (hasLinkedPlayer) {
                      firestoreService.isGuest = false;
                      return const MainShell();
                    }

                    return FutureBuilder<bool>(
                      future: firestoreService.hasGuestProfile(user.uid),
                      builder: (context, guestSnapshot) {
                        if (!guestSnapshot.hasData) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (guestSnapshot.data == true) {
                          firestoreService.isGuest = true;
                          firestoreService.guestUid = user.uid;
                          return const MainShell();
                        }
                        return const FamilyGateScreen();
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
