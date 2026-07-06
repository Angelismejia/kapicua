import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/round.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _players =>
      _db.collection('players');
  CollectionReference<Map<String, dynamic>> get _games =>
      _db.collection('games');

  // ---- Jugadores ----

  Stream<List<Player>> watchActivePlayers() {
    return _players.where('active', isEqualTo: true).orderBy('fullName').snapshots().map(
        (snap) => snap.docs.map((d) => Player.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Player>> watchAllPlayers() {
    return _players.orderBy('fullName').snapshots().map(
        (snap) => snap.docs.map((d) => Player.fromMap(d.id, d.data())).toList());
  }

  Future<void> addPlayer(String fullName, {String? shortName}) async {
    await _players.add(Player(
      id: '',
      fullName: fullName.trim(),
      shortName: (shortName == null || shortName.trim().isEmpty) ? null : shortName.trim(),
    ).toMap());
  }

  Future<void> removePlayer(String playerId) async {
    final used = await _games
        .where('participantIds', arrayContains: playerId)
        .limit(1)
        .get();
    if (used.docs.isEmpty) {
      await _players.doc(playerId).delete();
    } else {
      await _players.doc(playerId).update({'active': false});
    }
  }

  Future<void> reactivatePlayer(String playerId) async {
    await _players.doc(playerId).update({'active': true});
  }

  // ---- Partidas ----

  Stream<Game?> watchActiveGame() {
    return _games.where('status', isEqualTo: 'in_progress').limit(1).snapshots().map(
        (snap) => snap.docs.isEmpty ? null : Game.fromMap(snap.docs.first.id, snap.docs.first.data()));
  }

  Stream<Game?> watchGame(String gameId) {
    return _games.doc(gameId).snapshots().map(
        (doc) => doc.exists ? Game.fromMap(doc.id, doc.data()!) : null);
  }

  Stream<List<Game>> watchFinishedGames() {
    return _games
        .where('status', isEqualTo: 'finished')
        .orderBy('finishedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Game.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Round>> watchRounds(String gameId) {
    return _games
        .doc(gameId)
        .collection('rounds')
        .orderBy('roundNumber')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Round.fromMap(d.id, d.data())).toList());
  }

  Future<String> createGame(List<String> participantIds, int targetScore) async {
    final scores = {for (final id in participantIds) id: 0};
    final doc = await _games.add(Game(
      id: '',
      targetScore: targetScore,
      status: 'in_progress',
      participantIds: participantIds,
      scores: scores,
      createdAt: DateTime.now(),
    ).toMap());
    return doc.id;
  }

  Future<void> addRound(String gameId, Map<String, int> points) async {
    final gameRef = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final gameSnap = await tx.get(gameRef);
      final game = Game.fromMap(gameSnap.id, gameSnap.data()!);

      final newScores = Map<String, int>.from(game.scores);
      points.forEach((playerId, pts) {
        newScores[playerId] = (newScores[playerId] ?? 0) + pts;
      });

      final nextRoundNumber = game.roundCount + 1;
      final roundRef = gameRef.collection('rounds').doc();
      tx.set(roundRef, Round(
        id: roundRef.id,
        roundNumber: nextRoundNumber,
        points: points,
        createdAt: DateTime.now(),
      ).toMap());

      String? winnerId;
      newScores.forEach((playerId, total) {
        if (winnerId == null && total >= game.targetScore) {
          winnerId = playerId;
        }
      });

      tx.update(gameRef, {
        'scores': newScores,
        'roundCount': nextRoundNumber,
        'status': winnerId == null ? 'in_progress' : 'finished',
        'winnerId': winnerId,
        'finishedAt': winnerId == null ? null : Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  // ---- Estadísticas ----

  Stream<List<Game>> watchAllFinishedGamesForStats() {
    return _games
        .where('status', isEqualTo: 'finished')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Game.fromMap(d.id, d.data())).toList());
  }
}
