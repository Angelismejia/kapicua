import 'package:flutter_test/flutter_test.dart';
import 'package:kapicua/domain/entities/player.dart';
import 'package:kapicua/domain/entities/player_stat_entry.dart';
import 'package:kapicua/domain/usecases/monthly_winner.dart';

void main() {
  // Un mes ya cerrado (muy en el pasado respecto a "hoy"), para que el
  // corte del día 25 y el "mes ya terminó" se comporten siempre igual sin
  // importar qué día se corran los tests.
  final month = DateTime(2026, 3);

  DateTime onDay(int day) => DateTime(2026, 3, day);

  final playerA = Player(id: 'a', fullName: 'Ana');
  final playerB = Player(id: 'b', fullName: 'Beto');

  PlayerStatEntry entry(String playerId, bool isWin, int day) =>
      PlayerStatEntry(
        id: '$playerId-$day-$isWin',
        playerId: playerId,
        isWin: isWin,
        createdAt: onDay(day),
      );

  group('computeMonthlyWinner', () {
    test('sin ninguna entrada, no hay ganador', () {
      expect(computeMonthlyWinner([], [playerA, playerB], month), isNull);
    });

    test('sin ninguna ganada registrada, no hay ganador', () {
      final entries = [entry('a', false, 1), entry('b', false, 2)];
      expect(computeMonthlyWinner(entries, [playerA, playerB], month), isNull);
    });

    test('ignora entradas de otros meses', () {
      final entries = [
        entry('a', true, 1),
        PlayerStatEntry(
          id: 'other-month',
          playerId: 'b',
          isWin: true,
          createdAt: DateTime(2026, 4, 1),
        ),
      ];
      final winner = computeMonthlyWinner(entries, [playerA, playerB], month);
      expect(winner!.player.id, 'a');
    });

    test('sin nadie llegando a las 40 manos, gana el mejor porcentaje', () {
      final entries = [
        entry('a', true, 1),
        entry('a', false, 2),
        entry('b', true, 3),
      ];
      // A: 1-1 (50%), B: 1-0 (100%) — ninguno llega a 40 manos.
      final winner = computeMonthlyWinner(entries, [playerA, playerB], month);
      expect(winner!.player.id, 'b');
    });

    test(
      'quien llega a las 40 manos gana aunque su porcentaje sea peor '
      'que el de alguien que no llegó',
      () {
        final entries = <PlayerStatEntry>[
          for (var i = 0; i < 25; i++) entry('a', true, 1),
          for (var i = 0; i < 15; i++) entry('a', false, 1),
          entry('b', true, 2),
          entry('b', true, 2),
          entry('b', true, 2),
        ];
        // A: 25-15 (40 manos, 62.5%) sí califica.
        // B: 3-0 (100%) pero no llega a 40 manos.
        final winner = computeMonthlyWinner(
          entries,
          [playerA, playerB],
          month,
        );
        expect(winner!.player.id, 'a');
        expect(winner.wins, 25);
        expect(winner.losses, 15);
      },
    );

    test('certificateScore escala el porcentaje de 0 a 1000', () {
      final entries = [entry('a', true, 1), entry('a', true, 2)];
      final winner = computeMonthlyWinner(entries, [playerA], month);
      expect(winner!.wins, 2);
      expect(winner.losses, 0);
      expect(winner.certificateScore, 1000);
    });

    test('devuelve null si el jugador ganador ya no existe en la liga', () {
      final entries = [entry('a', true, 1)];
      expect(computeMonthlyWinner(entries, [playerB], month), isNull);
    });
  });

  group('qualifiedIdsForRanking', () {
    test('sin nadie llegando a las 40 manos, no filtra a nadie (null)', () {
      final result = qualifiedIdsForRanking({'a': 5}, {'a': 2}, month);
      expect(result, isNull);
    });

    test('con alguien llegando a las 40 manos, filtra a los que no', () {
      final result = qualifiedIdsForRanking(
        {'a': 25, 'b': 3},
        {'a': 15, 'b': 0},
        month,
      );
      expect(result, {'a'});
    });
  });

  group('computeMonthlyLeaderOrFallback', () {
    test('sin jugadores, no hay líder', () {
      expect(computeMonthlyLeaderOrFallback([], [], month), isNull);
    });

    test('sin ninguna entrada, igual devuelve un líder (0-0)', () {
      final leader = computeMonthlyLeaderOrFallback(
        [],
        [playerA, playerB],
        month,
      );
      expect(leader, isNotNull);
      expect(leader!.wins, 0);
      expect(leader.losses, 0);
    });

    test('en empate de porcentaje, desempata quien tiene más ganadas', () {
      final entries = [
        entry('a', true, 1),
        entry('a', false, 1),
        entry('b', true, 2),
        entry('b', true, 2),
        entry('b', false, 2),
        entry('b', false, 2),
      ];
      // A: 1-1 (50%), B: 2-2 (50%) — mismo porcentaje, pero B tiene más
      // ganadas.
      final leader = computeMonthlyLeaderOrFallback(
        entries,
        [playerA, playerB],
        month,
      );
      expect(leader!.player.id, 'b');
    });
  });

  group('computeMonthlyPercentageLeader', () {
    test('sin jugadores, no hay líder', () {
      expect(computeMonthlyPercentageLeader([], [], month), isNull);
    });

    test('elige a quien tiene mejor porcentaje de victorias', () {
      final entries = [
        entry('a', true, 1),
        entry('a', false, 1),
        entry('b', true, 2),
      ];
      final leader = computeMonthlyPercentageLeader(
        entries,
        [playerA, playerB],
        month,
      );
      expect(leader!.player.id, 'b');
      expect(leader.percentage, 100);
    });
  });
}
