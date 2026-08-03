import 'package:shared_preferences/shared_preferences.dart';

/// Recordado en este dispositivo (no en la cuenta), para que el tour de
/// bienvenida de Inicio salga una sola vez por celular/navegador.
class OnboardingService {
  static const _key = 'kapicua_home_tour_seen';

  Future<bool> hasSeenHomeTour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markHomeTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
