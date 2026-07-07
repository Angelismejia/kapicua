import '../models/player.dart';
import '../models/player_stat_entry.dart';

class MonthlyWinnerResult {
  final Player player;
  final DateTime month;
  final int wins;

  MonthlyWinnerResult({
    required this.player,
    required this.month,
    required this.wins,
  });

  bool get isMonthOver {
    final now = DateTime.now();
    if (now.year != month.year || now.month != month.month) return true;
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    return now.day >= lastDay;
  }
}

MonthlyWinnerResult? computeMonthlyWinner(
  List<PlayerStatEntry> entries,
  List<Player> players,
  DateTime month,
) {
  final winsCount = <String, int>{};
  for (final e in entries) {
    if (!e.isWin) continue;
    if (e.createdAt.year != month.year || e.createdAt.month != month.month) {
      continue;
    }
    winsCount[e.playerId] = (winsCount[e.playerId] ?? 0) + 1;
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
  );
}
