import '../models/player.dart';
import '../models/player_stat_entry.dart';

class MonthlyWinnerResult {
  final Player player;
  final DateTime month;
  final int wins;
  final int losses;

  MonthlyWinnerResult({
    required this.player,
    required this.month,
    required this.wins,
    required this.losses,
  });

  bool get isMonthOver {
    final now = DateTime.now();
    if (now.year != month.year || now.month != month.month) return true;
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return now.day >= lastDay;
  }

  /// Puntaje para el certificado: el porcentaje de victorias del mes
  /// llevado a una escala de 0 a 1000 (ej. 66.7% -> 667 puntos), para que
  /// el certificado muestre un número entero llamativo en vez de un
  /// porcentaje con decimales.
  int get certificateScore {
    final total = wins + losses;
    if (total == 0) return 0;
    return ((wins / total) * 1000).round();
  }
}

MonthlyWinnerResult? computeMonthlyWinner(
  List<PlayerStatEntry> entries,
  List<Player> players,
  DateTime month,
) {
  final winsCount = <String, int>{};
  final lossesCount = <String, int>{};
  for (final e in entries) {
    if (e.createdAt.year != month.year || e.createdAt.month != month.month) {
      continue;
    }
    if (e.isWin) {
      winsCount[e.playerId] = (winsCount[e.playerId] ?? 0) + 1;
    } else {
      lossesCount[e.playerId] = (lossesCount[e.playerId] ?? 0) + 1;
    }
  }
  if (winsCount.isEmpty) return null;

  String bestId = winsCount.keys.first;
  for (final id in winsCount.keys) {
    if (winsCount[id]! > winsCount[bestId]!) bestId = id;
  }

  final player = players
      .where((p) => p.id == bestId)
      .cast<Player?>()
      .firstWhere((_) => true, orElse: () => null);
  if (player == null) return null;

  return MonthlyWinnerResult(
    player: player,
    month: month,
    wins: winsCount[bestId]!,
    losses: lossesCount[bestId] ?? 0,
  );
}
