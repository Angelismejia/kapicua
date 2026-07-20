import '../repositories/player_repository.dart';

/// Une a dos fichas de jugador que en realidad son la misma persona (ej.
/// perdió el acceso a su cuenta vieja y se registró de nuevo con otro
/// correo, quedando dos jugadores separados con su mismo nombre). Todo
/// el historial del jugador que se elimina pasa a quedar bajo el que se
/// mantiene.
class MergePlayersUseCase {
  final PlayerRepository _playerRepository;

  MergePlayersUseCase(this._playerRepository);

  Future<void> call({
    required String keepPlayerId,
    required String removePlayerId,
  }) {
    return _playerRepository.mergePlayers(
      keepPlayerId: keepPlayerId,
      removePlayerId: removePlayerId,
    );
  }
}
