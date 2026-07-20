/// Ganador manual de meses viejos: para meses de antes de usar la app
/// (sin ninguna ganada/perdida registrada), un admin puede declarar a
/// mano quién fue el campeón, para que quede guardado en el historial
/// de certificados.
abstract class MonthlyOverrideRepository {
  Stream<Map<String, dynamic>?> watchMonthlyOverride(DateTime month);

  /// Todos los ganadores puestos a mano, llave "yyyy-MM" -> datos, para
  /// poder armar el historial completo de certificados de un jugador.
  Stream<Map<String, Map<String, dynamic>>> watchAllMonthlyOverrides();

  Future<void> setMonthlyOverride(
    DateTime month,
    String playerId,
    int wins,
    int losses,
  );

  Future<void> clearMonthlyOverride(DateTime month);
}
