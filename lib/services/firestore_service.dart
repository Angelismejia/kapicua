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

  // ---- Administradores ----
  // Un jugador es admin si su uid tiene un documento en "admins" (ademas
  // del respaldo por correo fijo en AuthService.kAdminEmails).

  Stream<Set<String>> watchAdminUids() {
    return _db
        .collection('admins')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  Future<void> grantAdmin(String uid) async {
    await _db.collection('admins').doc(uid).set({
      'grantedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> revokeAdmin(String uid) async {
    await _db.collection('admins').doc(uid).delete();
  }

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

  Future<void> updatePlayerPhoto(String playerId, String? photoBase64) async {
    await _players.doc(playerId).update({'photoBase64': photoBase64});
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

  /// Agrega varias ganadas/perdidas de una vez (ej. 13 ganadas ya jugadas
  /// antes de usar la app), en vez de tener que tocar el botón una por una.
  /// Si se pasa [date], se guardan con esa fecha (ej. el mes que se está
  /// viendo en el calendario) en vez de la fecha de hoy.
  Future<void> addPlayerStatEntries(
    String playerId,
    bool isWin,
    int count, {
    DateTime? date,
  }) async {
    final batch = _db.batch();
    final timestamp = Timestamp.fromDate(date ?? DateTime.now());
    final collection = _statEntries(playerId);
    for (var i = 0; i < count; i++) {
      batch.set(collection.doc(), {'isWin': isWin, 'createdAt': timestamp});
    }
    await batch.commit();
  }

  Future<void> deletePlayerStatEntry(String playerId, String entryId) async {
    await _statEntries(playerId).doc(entryId).delete();
  }

  /// Borra varias ganadas/perdidas de una vez (seleccionadas a mano),
  /// en vez de una por una.
  Future<void> deletePlayerStatEntries(
    String playerId,
    List<String> entryIds,
  ) async {
    final batch = _db.batch();
    final collection = _statEntries(playerId);
    for (final id in entryIds) {
      batch.delete(collection.doc(id));
    }
    await batch.commit();
  }

  /// Corrige la fecha de una ganada/perdida ya registrada, por si el admin
  /// se equivocó al anotarla.
  Future<void> updatePlayerStatEntryDate(
    String playerId,
    String entryId,
    DateTime newDate,
  ) async {
    await _statEntries(
      playerId,
    ).doc(entryId).update({'createdAt': Timestamp.fromDate(newDate)});
  }

  // ---- Partidas ----

  /// Puede haber varias partidas en curso a la vez (varias mesas jugando
  /// al mismo tiempo), asi que no se limita a una sola.
  Stream<List<Game>> watchActiveGames() {
    return _games
        .where('status', isEqualTo: 'in_progress')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => Game.fromMap(d.id, d.data())).toList(),
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

  /// Borra todas las partidas (terminadas y en curso) y sus rondas, por
  /// si se usaron partidas de prueba y se quiere empezar de cero antes de
  /// usar la app de verdad. No toca las estadísticas manuales.
  Future<void> clearGameHistory() async {
    final gamesSnap = await _games.get();
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

  /// Por si se marcó "ganada" por error (ej. un puntaje mal anotado que
  /// disparó la meta antes de tiempo): vuelve la partida a "en curso" para
  /// poder borrar la ronda equivocada y seguir jugando.
  Future<void> reopenGame(String gameId) async {
    await _games.doc(gameId).update({
      'status': 'in_progress',
      'winner': null,
      'finishedAt': null,
    });
  }

  /// Borra una ronda ya anotada y recalcula los totales y el estado de la
  /// partida a partir de las rondas restantes (por si esa ronda era la que
  /// hacía llegar a la meta).
  Future<void> deleteRound(String gameId, String roundId) async {
    final gameRef = _games.doc(gameId);
    final roundsRef = gameRef.collection('rounds');
    await roundsRef.doc(roundId).delete();

    final gameSnap = await gameRef.get();
    final game = Game.fromMap(gameSnap.id, gameSnap.data()!);
    final remaining = await roundsRef.orderBy('roundNumber').get();

    var totalA = 0;
    var totalB = 0;
    for (final doc in remaining.docs) {
      final round = Round.fromMap(doc.id, doc.data());
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
      'roundCount': remaining.docs.length,
      'status': winner == null ? 'in_progress' : 'finished',
      'winner': winner,
      'finishedAt': winner == null ? null : Timestamp.fromDate(DateTime.now()),
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
