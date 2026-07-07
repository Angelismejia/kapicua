import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda, solo en este dispositivo, cuál jugador de la liga es "yo"
/// para poder saludar por su nombre sin necesidad de un login real.
class DevicePlayerService extends ChangeNotifier {
  static const _prefsKey = 'device_player_id';
  String? _playerId;

  String? get playerId => _playerId;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _playerId = prefs.getString(_prefsKey);
    notifyListeners();
  }

  Future<void> setPlayer(String playerId) async {
    _playerId = playerId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, playerId);
  }
}
