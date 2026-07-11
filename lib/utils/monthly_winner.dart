import '../models/player.dart';
import '../models/player_stat_entry.dart';

/// Para ser declarado ganador de un mes ya cerrado hace falta haber
/// jugado al menos esta cantidad de manos (ganadas + perdidas) ese mes
/// — si nadie llega, el título se lo lleva igual quien tenga mejor
/// porcentaje, como antes. Solo aplica a partir de que se agregó esta
/// regla, no a certificados de meses viejos puestos a mano.
const kMinGamesToWinMonth = 40;

bool _monthHasEnded(DateTime month) {
  final now = DateTime.now();
  if (now.year != month.year || now.month != month.month) return true;
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  return now.day >= lastDay;
}

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

  bool get isMonthOver => _monthHasEnded(month);

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

  // Para ganar el título hay que haber jugado al menos
  // kMinGamesToWinMonth manos (ganadas + perdidas) ese mes — si nadie
  // llega, gana igual el de mejor porcentaje, como antes.
  bool qualifies(String id) =>
      (winsCount[id] ?? 0) + (lossesCount[id] ?? 0) >= kMinGamesToWinMonth;
  final anyoneQualifies = winsCount.keys.any(qualifies);

  // El "ganador" es quien tiene mejor porcentaje de victorias ese mes
  // (no simplemente quien tiene más ganadas), igual que en Estadísticas.
  String bestId = winsCount.keys.first;
  double bestPct = -1;
  for (final id in winsCount.keys) {
    if (anyoneQualifies && !qualifies(id)) continue;
    final w = winsCount[id]!;
    final l = lossesCount[id] ?? 0;
    final pct = w / (w + l);
    if (pct > bestPct) {
      bestPct = pct;
      bestId = id;
    }
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
/// nunca devuelve null (mientras haya al menos un jugador), incluso si
/// todavía nadie tiene una ganada registrada ese mes. A diferencia de
/// [computeMonthlyWinner] (que exige al menos una ganada), esta ordena a
/// TODOS los jugadores por porcentaje de victorias del mes (empate se
/// rompe por más ganadas) — el mismo cálculo y el mismo orden que la
/// lista de Estadísticas, para que el "líder" mostrado aquí sea siempre
/// el mismo que aparece arriba en Estadísticas.
MonthlyWinnerResult? computeMonthlyLeaderOrFallback(
  List<PlayerStatEntry> entries,
  List<Player> players,
  DateTime month,
) {
  if (players.isEmpty) return null;

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

  // Mientras el mes está en curso, no se exige nada todavía (puede que
  // alguien llegue a las manos mínimas antes de que se acabe). Una vez
  // cerrado, para ganar el título hay que haber jugado al menos
  // kMinGamesToWinMonth manos (ganadas + perdidas) ese mes — si nadie
  // llega, gana igual el de mejor porcentaje, como antes.
  final monthOver = _monthHasEnded(month);
  final anyoneQualifies =
      !monthOver ||
      players.any((p) {
        final total = (winsCount[p.id] ?? 0) + (lossesCount[p.id] ?? 0);
        return total >= kMinGamesToWinMonth;
      });

  var best = players.first;
  var bestPct = -1.0;
  var bestWins = -1;
  for (final p in players) {
    final w = winsCount[p.id] ?? 0;
    final l = lossesCount[p.id] ?? 0;
    final total = w + l;
    if (monthOver && anyoneQualifies && total < kMinGamesToWinMonth) {
      continue;
    }
    final pct = total == 0 ? 0.0 : w / total;
    if (pct > bestPct || (pct == bestPct && w > bestWins)) {
      bestPct = pct;
      bestWins = w;
      best = p;
    }
  }

  return MonthlyWinnerResult(
    player: best,
    month: month,
    wins: winsCount[best.id] ?? 0,
    losses: lossesCount[best.id] ?? 0,
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
