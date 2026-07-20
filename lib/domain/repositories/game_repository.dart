import '../entities/game.dart';
import '../entities/round.dart';

abstract class GameRepository {
  /// Puede haber varias partidas en curso a la vez (varias mesas jugando
  /// al mismo tiempo), asi que no se limita a una sola.
  Stream<List<Game>> watchActiveGames();

  Stream<Game?> watchGame(String gameId);

  Stream<List<Game>> watchFinishedGames();

  /// Partidas ya terminadas, con ganador y jugadores de verdad, a las que
  /// todavía no se les decidió si sumarlas a Estadísticas o ignorarlas.
  Stream<List<Game>> watchPendingStatsGames();

  /// Le suma la ganada a cada jugador del equipo ganador y la perdida a
  /// cada uno del equipo perdedor, y marca la partida como ya resuelta.
  Future<void> applyGameStats(Game game);

  /// Descarta la sugerencia de una partida puntual para siempre, sin
  /// tocar las estadísticas.
  Future<void> ignoreGameStats(String gameId);

  Stream<List<Round>> watchRounds(String gameId);

  Future<String> createGame(
    List<String> teamAPlayerIds,
    List<String> teamBPlayerIds,
    int targetScore,
  );

  /// Reinicia una partida en curso a 0-0 sin tocar quiénes juegan.
  Future<void> resetGame(String gameId);

  /// Cancela una partida en curso por completo: borra la partida y sus
  /// rondas, sin dejar nada para seguir jugando.
  Future<void> cancelGame(String gameId);

  /// Borra todas las partidas (terminadas y en curso) y sus rondas.
  Future<void> clearGameHistory();

  Future<void> addRound(String gameId, int teamAPoints, int teamBPoints);

  /// Vuelve la partida a "en curso" para poder borrar la ronda equivocada
  /// y seguir jugando.
  Future<void> reopenGame(String gameId);

  /// Cambia el nombre mostrado de "Casa" o "Visita" solo para esta
  /// partida, sin afectar a los jugadores ni a otras partidas.
  Future<void> renameGameTeam(String gameId, String team, String label);

  /// Corrige el puntaje de una ronda ya anotada y recalcula los totales y
  /// el estado de la partida.
  Future<void> updateRound(
    String gameId,
    String roundId,
    int teamAPoints,
    int teamBPoints,
  );

  /// Borra una ronda ya anotada y recalcula los totales y el estado de la
  /// partida a partir de las rondas restantes.
  Future<void> deleteRound(String gameId, String roundId);
}
