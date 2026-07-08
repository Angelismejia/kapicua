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

  int get totalGames => wins + losses;

  double get winPercentage {
    if (totalGames == 0) return 0;
    return (wins / totalGames) * 100;
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

/// Como siempre hay alguien "arriba" en cualquier tabla, esta variante
/// nunca devuelve null (mientras haya al menos un jugador): si todavía
/// nadie tiene una ganada registrada ese mes, muestra al primero de la
/// lista con sus ganadas/perdidas reales de ese mes (probablemente 0),
/// en vez de dejar la tarjeta de campeón "sin definir".
MonthlyWinnerResult? computeMonthlyLeaderOrFallback(
  List<PlayerStatEntry> entries,
  List<Player> players,
  DateTime month,
) {
  final real = computeMonthlyWinner(entries, players, month);
  if (real != null) return real;
  if (players.isEmpty) return null;

  final leader = players.first;
  var losses = 0;
  for (final e in entries) {
    if (e.playerId == leader.id &&
        !e.isWin &&
        e.createdAt.year == month.year &&
        e.createdAt.month == month.month) {
      losses++;
    }
  }
  return MonthlyWinnerResult(
    player: leader,
    month: month,
    wins: 0,
    losses: losses,
  );
}

/// A diferencia de [computeMonthlyWinner] (que ordena por cantidad de
/// ganadas), esto ordena por porcentaje de victorias del mes — usado en
/// el carrusel de Inicio, igual que el orden de Estadísticas.
class MonthlyPercentageLeader {
  final Player player;
  final int wins;
  final int losses;

  MonthlyPercentageLeader({
    required this.player,
    required this.wins,
    required this.losses,
  });

  int get total => wins + losses;

  double get percentage => total == 0 ? 0 : (wins / total) * 100;
}

MonthlyPercentageLeader? computeMonthlyPercentageLeader(
  List<PlayerStatEntry> entries,
  List<Player> players,
  DateTime month,
) {
  if (players.isEmpty) return null;

  final wins = <String, int>{};
  final losses = <String, int>{};
  for (final e in entries) {
    if (e.createdAt.year != month.year || e.createdAt.month != month.month) {
      continue;
    }
    if (e.isWin) {
      wins[e.playerId] = (wins[e.playerId] ?? 0) + 1;
    } else {
      losses[e.playerId] = (losses[e.playerId] ?? 0) + 1;
    }
  }

  var best = players.first;
  var bestPct = -1.0;
  for (final p in players) {
    final w = wins[p.id] ?? 0;
    final l = losses[p.id] ?? 0;
    final total = w + l;
    final pct = total == 0 ? 0.0 : (w / total) * 100;
    if (pct > bestPct) {
      bestPct = pct;
      best = p;
    }
  }
  return MonthlyPercentageLeader(
    player: best,
    wins: wins[best.id] ?? 0,
    losses: losses[best.id] ?? 0,
  );
}
