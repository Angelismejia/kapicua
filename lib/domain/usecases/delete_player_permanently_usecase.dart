import '../repositories/player_repository.dart';

/// Solo deja borrar a un jugador para siempre si nunca tuvo ganadas,
/// perdidas ni partidas registradas — si no, se perdería su historial de
/// certificados y estadísticas. Lanza una excepción con un mensaje listo
/// para mostrar si el jugador sí tiene historial.
class DeletePlayerPermanentlyUseCase {
  final PlayerRepository _playerRepository;

  DeletePlayerPermanentlyUseCase(this._playerRepository);

  Future<void> call(String playerId) {
    return _playerRepository.deletePlayerPermanently(playerId);
  }
}
