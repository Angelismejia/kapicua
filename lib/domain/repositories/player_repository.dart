import '../entities/player.dart';

abstract class PlayerRepository {
  /// Busca solo el jugador vinculado a esta cuenta (consulta puntual, no
  /// un listener), para decidir a dónde entrar justo después de iniciar
  /// sesión sin tener que esperar a cargar toda la lista de la liga.
  Future<Player?> findPlayerByAuthUid(String uid);

  /// Vigila un jugador puntual (ej. para que la pantalla de perfil se
  /// actualice sola justo después de cambiar la foto).
  Stream<Player?> watchPlayer(String playerId);

  Stream<List<Player>> watchActivePlayers();

  Stream<List<Player>> watchAllPlayers();

  Future<void> addPlayer(String fullName, {String? shortName});

  Future<void> removePlayer(String playerId);

  Future<void> reactivatePlayer(String playerId);

  Future<void> updatePlayer(
    String playerId,
    String fullName, {
    String? shortName,
  });

  Future<void> updatePlayerPhoto(String playerId, String? photoBase64);

  /// Elimina el jugador de forma permanente. Solo se deja si nunca tuvo
  /// ganadas, perdidas ni partidas registradas — si no, se perdería su
  /// historial de certificados y estadísticas para siempre.
  Future<void> deletePlayerPermanently(String playerId);

  /// Une a dos fichas de jugador que en realidad son la misma persona.
  /// Todo el historial de [removePlayerId] pasa a quedar bajo
  /// [keepPlayerId], y [removePlayerId] se borra al final.
  Future<void> mergePlayers({
    required String keepPlayerId,
    required String removePlayerId,
  });

  /// Crea la ficha de un jugador nuevo de la familia durante el registro,
  /// ya vinculada a su cuenta. A diferencia de [addPlayer], esto siempre
  /// usa la colección de la familia (nunca el espacio de un invitado),
  /// porque el registro familiar es siempre para la liga real. Devuelve
  /// un mensaje de error listo para mostrar si algo falla, o null si
  /// todo salió bien (mismo patrón que AuthRepository).
  Future<String?> createFamilyPlayerForSignup(
    String fullName, {
    String? shortName,
    required String authUid,
  });

  /// Vincula una ficha de jugador ya existente (elegida en la pantalla
  /// anterior) a la cuenta recién creada o iniciada.
  Future<String?> linkPlayerToAuth(String playerId, String authUid);
}
