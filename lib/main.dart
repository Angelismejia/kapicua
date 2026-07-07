import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/main_shell.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'services/device_player_service.dart';
import 'services/firestore_service.dart';
import 'services/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es');
  await AuthService().ensureSignedIn();
  final themeController = ThemeController();
  await themeController.load();
  final devicePlayerService = DevicePlayerService();
  await devicePlayerService.load();
  final adminService = AdminService();
  await adminService.load();
  runApp(
    KapicuaApp(
      themeController: themeController,
      devicePlayerService: devicePlayerService,
      adminService: adminService,
    ),
  );
}

class KapicuaApp extends StatelessWidget {
  final ThemeController themeController;
  final DevicePlayerService devicePlayerService;
  final AdminService adminService;

  const KapicuaApp({
    super.key,
    required this.themeController,
    required this.devicePlayerService,
    required this.adminService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ChangeNotifierProvider<DevicePlayerService>.value(
          value: devicePlayerService,
        ),
        ChangeNotifierProvider<AdminService>.value(value: adminService),
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
            home: const MainShell(),
          );
        },
      ),
    );
  }
}
