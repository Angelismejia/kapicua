/// Ganador manual de meses viejos: para meses de antes de usar la app
/// (sin ninguna ganada/perdida registrada), un admin puede declarar a
/// mano quién fue el campeón, para que quede guardado en el historial
/// de certificados.
abstract class MonthlyOverrideRepository {
  Stream<Map<String, dynamic>?> watchMonthlyOverride(DateTime month);

  /// Todos los ganadores puestos a mano, llave "yyyy-MM" -> datos, para
  /// poder armar el historial completo de certificados de un jugador.
  Stream<Map<String, Map<String, dynamic>>> watchAllMonthlyOverrides();

  /// Los datos de subcampeón son opcionales: si se omiten, el mes queda
  /// solo con campeón puesto a mano (igual que antes). Siempre se
  /// escriben ambos juntos, así que para quitar solo el subcampeón basta
  /// con volver a llamar esto sin esos parámetros.
  Future<void> setMonthlyOverride(
    DateTime month,
    String playerId,
    int wins,
    int losses, {
    String? secondPlacePlayerId,
    int? secondPlaceWins,
    int? secondPlaceLosses,
  });

  Future<void> clearMonthlyOverride(DateTime month);
}
