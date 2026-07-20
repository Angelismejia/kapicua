import '../entities/player_stat_entry.dart';

abstract class StatsRepository {
  Stream<List<PlayerStatEntry>> watchPlayerStatEntries(String playerId);

  Stream<List<PlayerStatEntry>> watchAllStatEntries();

  Future<void> addPlayerStatEntry(String playerId, bool isWin);

  /// Agrega varias ganadas/perdidas de una vez. Si se pasa [date], se
  /// guardan con esa fecha en vez de la fecha de hoy.
  Future<void> addPlayerStatEntries(
    String playerId,
    bool isWin,
    int count, {
    DateTime? date,
  });

  Future<void> deletePlayerStatEntry(String playerId, String entryId);

  /// Borra varias ganadas/perdidas de una vez (seleccionadas a mano).
  Future<void> deletePlayerStatEntries(String playerId, List<String> entryIds);

  /// Corrige la fecha de una ganada/perdida ya registrada.
  Future<void> updatePlayerStatEntryDate(
    String playerId,
    String entryId,
    DateTime newDate,
  );
}
