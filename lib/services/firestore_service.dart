import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game.dart';
import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../models/round.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Si es true, todas las colecciones usadas son el espacio propio del
  /// invitado (guestSpaces/{guestUid}) en vez de los datos de la familia.
  bool isGuest = false;
  String? guestUid;

  CollectionReference<Map<String, dynamic>> get _players => isGuest
      ? _db.collection('guestSpaces').doc(guestUid).collection('players')
      : _db.collection('players');
  CollectionReference<Map<String, dynamic>> get _games => isGuest
      ? _db.collection('guestSpaces').doc(guestUid).collection('games')
      : _db.collection('games');

  // ---- Jugadores ----

  Stream<List<Player>> watchActivePlayers() {
    return _players
        .where('active', isEqualTo: true)
        .orderBy('fullName')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Player.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<List<Player>> watchAllPlayers() {
    return _players
        .orderBy('fullName')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Player.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> addPlayer(String fullName, {String? shortName}) async {
    await _players.add(
      Player(
        id: '',
        fullName: fullName.trim(),
        shortName: (shortName == null || shortName.trim().isEmpty)
            ? null
            : shortName.trim(),
      ).toMap(),
    );
  }

  Future<void> removePlayer(String playerId) async {
    final usedInA = await _games
        .where('teamAPlayerIds', arrayContains: playerId)
        .limit(1)
        .get();
    final usedInB = usedInA.docs.isNotEmpty
        ? usedInA
        : await _games
              .where('teamBPlayerIds', arrayContains: playerId)
              .limit(1)
              .get();
    if (usedInA.docs.isEmpty && usedInB.docs.isEmpty) {
      await _players.doc(playerId).delete();
    } else {
      await _players.doc(playerId).update({'active': false});
    }
  }

  Future<void> reactivatePlayer(String playerId) async {
    await _players.doc(playerId).update({'active': true});
  }

  Future<void> updatePlayer(
    String playerId,
    String fullName, {
    String? shortName,
  }) async {
    await _players.doc(playerId).update({
      'fullName': fullName.trim(),
      'shortName': (shortName == null || shortName.trim().isEmpty)
          ? null
          : shortName.trim(),
    });
  }

  /// Elimina el jugador de forma permanente, incluso si ya jugó partidas.
  /// Su nombre dejará de poder mostrarse en partidas/certificados antiguos.
  Future<void> deletePlayerPermanently(String playerId) async {
    await _players.doc(playerId).delete();
  }

  // ---- Historial manual de ganadas/perdidas ----
  // Las estadísticas no dependen de las partidas anotadas en la app: el
  // administrador agrega cada ganada/perdida a mano, con su fecha.

  CollectionReference<Map<String, dynamic>> _statEntries(String playerId) =>
      _players.doc(playerId).collection('statEntries');

  Stream<List<PlayerStatEntry>> watchPlayerStatEntries(String playerId) {
    return _statEntries(playerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PlayerStatEntry.fromMap(d.id, playerId, d.data()))
              .toList(),
        );
  }

  Stream<List<PlayerStatEntry>> watchAllStatEntries() {
    return _db.collectionGroup('statEntries').snapshots().map((snap) {
      return snap.docs.map((d) {
        final playerId = d.reference.parent.parent!.id;
        return PlayerStatEntry.fromMap(d.id, playerId, d.data());
      }).toList();
    });
  }

  Future<void> addPlayerStatEntry(String playerId, bool isWin) async {
    await _statEntries(
      playerId,
    ).add({'isWin': isWin, 'createdAt': Timestamp.fromDate(DateTime.now())});
  }

  Future<void> deletePlayerStatEntry(String playerId, String entryId) async {
    await _statEntries(playerId).doc(entryId).delete();
  }

  // ---- Partidas ----

  Stream<Game?> watchActiveGame() {
    return _games
        .where('status', isEqualTo: 'in_progress')
        .limit(1)
        .snapshots()
        .map(
          (snap) => snap.docs.isEmpty
              ? null
              : Game.fromMap(snap.docs.first.id, snap.docs.first.data()),
        );
  }

  Stream<Game?> watchGame(String gameId) {
    return _games
        .doc(gameId)
        .snapshots()
        .map((doc) => doc.exists ? Game.fromMap(doc.id, doc.data()!) : null);
  }

  Stream<List<Game>> watchFinishedGames() {
    return _games
        .where('status', isEqualTo: 'finished')
        .orderBy('finishedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => Game.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<List<Round>> watchRounds(String gameId) {
    return _games
        .doc(gameId)
        .collection('rounds')
        .orderBy('roundNumber')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Round.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<String> createGame(
    List<String> teamAPlayerIds,
    List<String> teamBPlayerIds,
    int targetScore,
  ) async {
    final doc = await _games.add(
      Game(
        id: '',
        targetScore: targetScore,
        status: 'in_progress',
        teamAPlayerIds: teamAPlayerIds,
        teamBPlayerIds: teamBPlayerIds,
        createdAt: DateTime.now(),
      ).toMap(),
    );
    return doc.id;
  }

  /// Cancela una partida en curso (por si se quiere reiniciar) sin
  /// contarla como jugada. Borra también las rondas ya anotadas.
  Future<void> cancelGame(String gameId) async {
    final roundsSnap = await _games.doc(gameId).collection('rounds').get();
    final batch = _db.batch();
    for (final doc in roundsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_games.doc(gameId));
    await batch.commit();
  }

  Future<void> addRound(String gameId, int teamAPoints, int teamBPoints) async {
    final gameRef = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final gameSnap = await tx.get(gameRef);
      final game = Game.fromMap(gameSnap.id, gameSnap.data()!);

      final newA = game.teamAScore + teamAPoints;
      final newB = game.teamBScore + teamBPoints;
      final nextRoundNumber = game.roundCount + 1;
      final roundRef = gameRef.collection('rounds').doc();
      tx.set(
        roundRef,
        Round(
          id: roundRef.id,
          roundNumber: nextRoundNumber,
          teamAPoints: teamAPoints,
          teamBPoints: teamBPoints,
          createdAt: DateTime.now(),
        ).toMap(),
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

  // ---- Invitados (fuera de la familia) ----

  Future<bool> hasGuestProfile(String uid) async {
    final doc = await _db.collection('guestSpaces').doc(uid).get();
    return doc.exists;
  }

  Future<void> createGuestProfile(String uid) async {
    await _db.collection('guestSpaces').doc(uid).set({
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
