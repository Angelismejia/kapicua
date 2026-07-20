import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/game.dart';
import '../../domain/entities/guest_session.dart';
import '../../domain/entities/round.dart';
import '../../domain/repositories/game_repository.dart';
import '../models/game_dto.dart';
import '../models/round_dto.dart';
import 'firestore_collections.dart';

class FirestoreGameRepository implements GameRepository {
  final FirebaseFirestore _db;
  final FirestoreCollections _collections;

  FirestoreGameRepository(FirebaseFirestore db, GuestSession session)
    : _db = db,
      _collections = FirestoreCollections(db, session);

  @override
  Stream<List<Game>> watchActiveGames() {
    return _collections.games
        .where('status', isEqualTo: 'in_progress')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => GameDto.fromMap(d.id, d.data())).toList(),
        );
  }

  @override
  Stream<Game?> watchGame(String gameId) {
    return _collections.games
        .doc(gameId)
        .snapshots()
        .map((doc) => doc.exists ? GameDto.fromMap(doc.id, doc.data()!) : null);
  }

  @override
  Stream<List<Game>> watchFinishedGames() {
    return _collections.games
        .where('status', isEqualTo: 'finished')
        .orderBy('finishedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => GameDto.fromMap(d.id, d.data())).toList(),
        );
  }

  @override
  Stream<List<Game>> watchPendingStatsGames() {
    return _collections.games
        .where('status', isEqualTo: 'finished')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => GameDto.fromMap(d.id, d.data()))
              .where(
                (g) =>
                    g.statsResolution == null &&
                    g.winner != null &&
                    g.teamAPlayerIds.isNotEmpty &&
                    g.teamBPlayerIds.isNotEmpty,
              )
              .toList(),
        );
  }

  @override
  Future<void> applyGameStats(Game game) async {
    final batch = _db.batch();
    final date = Timestamp.fromDate(game.finishedAt ?? DateTime.now());
    final winningTeam = game.winner == 'A'
        ? game.teamAPlayerIds
        : game.teamBPlayerIds;
    final losingTeam = game.winner == 'A'
        ? game.teamBPlayerIds
        : game.teamAPlayerIds;
    for (final playerId in winningTeam) {
      batch.set(_collections.statEntries(playerId).doc(), {
        'isWin': true,
        'createdAt': date,
      });
    }
    for (final playerId in losingTeam) {
      batch.set(_collections.statEntries(playerId).doc(), {
        'isWin': false,
        'createdAt': date,
      });
    }
    batch.update(_collections.games.doc(game.id), {'statsResolution': 'added'});
    await batch.commit();
  }

  @override
  Future<void> ignoreGameStats(String gameId) async {
    await _collections.games.doc(gameId).update({'statsResolution': 'ignored'});
  }

  @override
  Stream<List<Round>> watchRounds(String gameId) {
    return _collections.games
        .doc(gameId)
        .collection('rounds')
        .orderBy('roundNumber')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => RoundDto.fromMap(d.id, d.data())).toList(),
        );
  }

  @override
  Future<String> createGame(
    List<String> teamAPlayerIds,
    List<String> teamBPlayerIds,
    int targetScore,
  ) async {
    final doc = await _collections.games.add(
      GameDto.toMap(
        Game(
          id: '',
          targetScore: targetScore,
          status: 'in_progress',
          teamAPlayerIds: teamAPlayerIds,
          teamBPlayerIds: teamBPlayerIds,
          createdAt: DateTime.now(),
        ),
      ),
    );
    return doc.id;
  }

  @override
  Future<void> resetGame(String gameId) async {
    final gameRef = _collections.games.doc(gameId);
    final roundsSnap = await gameRef.collection('rounds').get();
    final batch = _db.batch();
    for (final doc in roundsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.update(gameRef, {
      'teamAScore': 0,
      'teamBScore': 0,
      'roundCount': 0,
      'status': 'in_progress',
      'winner': null,
      'finishedAt': null,
    });
    await batch.commit();
  }

  @override
  Future<void> cancelGame(String gameId) async {
    final gameRef = _collections.games.doc(gameId);
    final roundsSnap = await gameRef.collection('rounds').get();
    final batch = _db.batch();
    for (final doc in roundsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(gameRef);
    await batch.commit();
  }

  @override
  Future<void> clearGameHistory() async {
    final gamesSnap = await _collections.games.get();
    for (final gameDoc in gamesSnap.docs) {
      final roundsSnap = await gameDoc.reference.collection('rounds').get();
      final batch = _db.batch();
      for (final round in roundsSnap.docs) {
        batch.delete(round.reference);
      }
      batch.delete(gameDoc.reference);
      await batch.commit();
    }
  }

  @override
  Future<void> addRound(
    String gameId,
    int teamAPoints,
    int teamBPoints,
  ) async {
    final gameRef = _collections.games.doc(gameId);
    await _db.runTransaction((tx) async {
      final gameSnap = await tx.get(gameRef);
      final game = GameDto.fromMap(gameSnap.id, gameSnap.data()!);

      final newA = game.teamAScore + teamAPoints;
      final newB = game.teamBScore + teamBPoints;
      final nextRoundNumber = game.roundCount + 1;
      final roundRef = gameRef.collection('rounds').doc();
      tx.set(
        roundRef,
        RoundDto.toMap(
          Round(
            id: roundRef.id,
            roundNumber: nextRoundNumber,
            teamAPoints: teamAPoints,
            teamBPoints: teamBPoints,
            createdAt: DateTime.now(),
          ),
        ),
      );

      String? winner;
      final aReached = newA >= game.targetScore;
      final bReached = newB >= game.targetScore;
      if (aReached || bReached) {
        winner = newA >= newB ? 'A' : 'B';
      }

      tx.update(gameRef, {
        'teamAScore': newA,
        'teamBScore': newB,
        'roundCount': nextRoundNumber,
        'status': winner == null ? 'in_progress' : 'finished',
        'winner': winner,
        'finishedAt': winner == null
            ? null
            : Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  @override
  Future<void> reopenGame(String gameId) async {
    await _collections.games.doc(gameId).update({
      'status': 'in_progress',
      'winner': null,
      'finishedAt': null,
    });
  }

  @override
  Future<void> renameGameTeam(String gameId, String team, String label) async {
    await _collections.games.doc(gameId).update({
      team == 'A' ? 'teamALabel' : 'teamBLabel': label,
    });
  }

  @override
  Future<void> updateRound(
    String gameId,
    String roundId,
    int teamAPoints,
    int teamBPoints,
  ) async {
    final gameRef = _collections.games.doc(gameId);
    final roundsRef = gameRef.collection('rounds');
    await roundsRef.doc(roundId).update({
      'teamAPoints': teamAPoints,
      'teamBPoints': teamBPoints,
    });

    final gameSnap = await gameRef.get();
    final game = GameDto.fromMap(gameSnap.id, gameSnap.data()!);
    final remaining = await roundsRef.orderBy('roundNumber').get();

    var totalA = 0;
    var totalB = 0;
    for (final doc in remaining.docs) {
      final round = RoundDto.fromMap(doc.id, doc.data());
      totalA += round.teamAPoints;
      totalB += round.teamBPoints;
    }

    String? winner;
    if (totalA >= game.targetScore || totalB >= game.targetScore) {
      winner = totalA >= totalB ? 'A' : 'B';
    }

    await gameRef.update({
      'teamAScore': totalA,
      'teamBScore': totalB,
      'status': winner == null ? 'in_progress' : 'finished',
      'winner': winner,
      'finishedAt': winner == null ? null : Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<void> deleteRound(String gameId, String roundId) async {
    final gameRef = _collections.games.doc(gameId);
    final roundsRef = gameRef.collection('rounds');
    await roundsRef.doc(roundId).delete();

    final gameSnap = await gameRef.get();
    final game = GameDto.fromMap(gameSnap.id, gameSnap.data()!);
    final remaining = await roundsRef.orderBy('roundNumber').get();

    var totalA = 0;
    var totalB = 0;
    var maxRoundNumber = 0;
    for (final doc in remaining.docs) {
      final round = RoundDto.fromMap(doc.id, doc.data());
      totalA += round.teamAPoints;
      totalB += round.teamBPoints;
      if (round.roundNumber > maxRoundNumber) {
        maxRoundNumber = round.roundNumber;
      }
    }

    String? winner;
    if (totalA >= game.targetScore || totalB >= game.targetScore) {
      winner = totalA >= totalB ? 'A' : 'B';
    }

    await gameRef.update({
      'teamAScore': totalA,
      'teamBScore': totalB,
      // No es simplemente "cuántas rondas quedan": si se borró una de en
      // medio (no la última), la cantidad restante es menor que el número
      // más alto ya usado, y una ronda nueva agregada después chocaría con
      // ese número repetido. Se guarda el número más alto en uso para que
      // la siguiente ronda siga contando para arriba sin repetirse.
      'roundCount': maxRoundNumber,
      'status': winner == null ? 'in_progress' : 'finished',
      'winner': winner,
      'finishedAt': winner == null ? null : Timestamp.fromDate(DateTime.now()),
    });
  }
}
