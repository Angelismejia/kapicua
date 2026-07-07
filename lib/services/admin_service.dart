import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PIN compartido para desbloquear el modo administrador en este dispositivo.
/// Solo quienes lo conozcan (papá y Bladimir) pueden gestionar jugadores
/// y estadísticas manuales. Se pasa en tiempo de compilación
/// (--dart-define=ADMIN_PIN=...) para que no quede escrito en el código.
const String kAdminPin = String.fromEnvironment(
  'ADMIN_PIN',
  defaultValue: '0000',
);

class AdminService extends ChangeNotifier {
  static const _prefsKey = 'is_admin_unlocked';
  bool _isAdmin = false;

  bool get isAdmin => _isAdmin;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isAdmin = prefs.getBool(_prefsKey) ?? false;
    notifyListeners();
  }

  Future<bool> unlock(String pin) async {
    if (pin.trim() != kAdminPin) return false;
    _isAdmin = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    return true;
  }

  Future<void> lock() async {
    _isAdmin = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, false);
  }
}
