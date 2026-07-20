import '../entities/game.dart';
import '../repositories/game_repository.dart';

/// Le suma la ganada a cada jugador del equipo ganador y la perdida a
/// cada uno del equipo perdedor, y marca la partida como ya resuelta
/// para que no se vuelva a sugerir.
class ApplyGameStatsUseCase {
  final GameRepository _gameRepository;

  ApplyGameStatsUseCase(this._gameRepository);

  Future<void> call(Game game) => _gameRepository.applyGameStats(game);
}

/// Agrega una ronda anotada a la partida: suma los puntos, y si algún
/// equipo llega a la meta, marca la partida como terminada y guarda quién
/// ganó.
class AddRoundUseCase {
  final GameRepository _gameRepository;

  AddRoundUseCase(this._gameRepository);

  Future<void> call(String gameId, int teamAPoints, int teamBPoints) {
    return _gameRepository.addRound(gameId, teamAPoints, teamBPoints);
  }
}

/// Corrige el puntaje de una ronda ya anotada (por si se equivocaron al
/// escribirlo) y recalcula los totales y el estado de la partida.
class UpdateRoundUseCase {
  final GameRepository _gameRepository;

  UpdateRoundUseCase(this._gameRepository);

  Future<void> call(
    String gameId,
    String roundId,
    int teamAPoints,
    int teamBPoints,
  ) {
    return _gameRepository.updateRound(
      gameId,
      roundId,
      teamAPoints,
      teamBPoints,
    );
  }
}

/// Borra una ronda ya anotada y recalcula los totales y el estado de la
/// partida a partir de las rondas restantes (por si esa ronda era la que
/// hacía llegar a la meta).
class DeleteRoundUseCase {
  final GameRepository _gameRepository;

  DeleteRoundUseCase(this._gameRepository);

  Future<void> call(String gameId, String roundId) {
    return _gameRepository.deleteRound(gameId, roundId);
  }
}
