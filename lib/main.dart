import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
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
  runApp(
    KapicuaApp(
      themeController: themeController,
      devicePlayerService: devicePlayerService,
    ),
  );
}

class KapicuaApp extends StatelessWidget {
  final ThemeController themeController;
  final DevicePlayerService devicePlayerService;

  const KapicuaApp({
    super.key,
    required this.themeController,
    required this.devicePlayerService,
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
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E7D32),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
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
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
