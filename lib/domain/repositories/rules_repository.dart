import '../entities/rule.dart';

/// Reglas de la liga, visibles para toda la familia pero editables solo
/// por un admin (por ahora es solo texto libre, ordenado por creación).
abstract class RulesRepository {
  Stream<List<Rule>> watchRules();

  Future<void> addRule(String text);

  Future<void> updateRule(String ruleId, String text);

  Future<void> deleteRule(String ruleId);
}
