import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/guest_session.dart';
import '../../domain/entities/player.dart';
import '../../domain/repositories/player_repository.dart';
import '../models/player_dto.dart';
import 'firestore_collections.dart';

class FirestorePlayerRepository implements PlayerRepository {
  final FirebaseFirestore _db;
  final FirestoreCollections _collections;

  FirestorePlayerRepository(FirebaseFirestore db, GuestSession session)
    : _db = db,
      _collections = FirestoreCollections(db, session);

  @override
  Future<Player?> findPlayerByAuthUid(String uid) async {
    final snap = await _collections.players
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return PlayerDto.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  @override
  Stream<Player?> watchPlayer(String playerId) {
    return _collections.players
        .doc(playerId)
        .snapshots()
        .map((doc) => doc.exists ? PlayerDto.fromMap(doc.id, doc.data()!) : null);
  }

  @override
  Stream<List<Player>> watchActivePlayers() {
    return _collections.players
        .where('active', isEqualTo: true)
        .orderBy('fullName')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => PlayerDto.fromMap(d.id, d.data())).toList(),
        );
  }

  @override
  Stream<List<Player>> watchAllPlayers() {
    return _collections.players
        .orderBy('fullName')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => PlayerDto.fromMap(d.id, d.data())).toList(),
        );
  }

  @override
  Future<void> addPlayer(String fullName, {String? shortName}) async {
    await _collections.players.add(
      PlayerDto.toMap(
        Player(
          id: '',
          fullName: fullName.trim(),
          shortName: (shortName == null || shortName.trim().isEmpty)
              ? null
              : shortName.trim(),
        ),
      ),
    );
  }

  @override
  Future<void> removePlayer(String playerId) async {
    await _collections.players.doc(playerId).update({'active': false});
  }

  @override
  Future<void> reactivatePlayer(String playerId) async {
    await _collections.players.doc(playerId).update({'active': true});
  }

  @override
  Future<void> updatePlayer(
    String playerId,
    String fullName, {
    String? shortName,
  }) async {
    await _collections.players.doc(playerId).update({
      'fullName': fullName.trim(),
      'shortName': (shortName == null || shortName.trim().isEmpty)
          ? null
          : shortName.trim(),
    });
  }

  @override
  Future<void> updatePlayerPhoto(String playerId, String? photoBase64) async {
    await _collections.players.doc(playerId).update({'photoBase64': photoBase64});
  }

  /// Si ya tiene alguna ganada o perdida registrada, o jugó alguna
  /// partida, borrarlo del todo haría que desaparezca de certificados y
  /// estadísticas viejas.
  Future<bool> _hasHistory(String playerId) async {
    final hasStats = await _collections.statEntries(playerId).limit(1).get();
    if (hasStats.docs.isNotEmpty) return true;
    final usedInA = await _collections.games
        .where('teamAPlayerIds', arrayContains: playerId)
        .limit(1)
        .get();
    if (usedInA.docs.isNotEmpty) return true;
    final usedInB = await _collections.games
        .where('teamBPlayerIds', arrayContains: playerId)
        .limit(1)
        .get();
    return usedInB.docs.isNotEmpty;
  }

  @override
  Future<void> deletePlayerPermanently(String playerId) async {
    if (await _hasHistory(playerId)) {
      throw Exception(
        'No se puede eliminar para siempre: tiene ganadas, perdidas o '
        'partidas registradas y se perderían de las estadísticas y '
        'certificados. Puedes dejarlo inactivo en su lugar.',
      );
    }
    await _collections.players.doc(playerId).delete();
  }

  @override
  Future<void> mergePlayers({
    required String keepPlayerId,
    required String removePlayerId,
  }) async {
    if (keepPlayerId == removePlayerId) {
      throw Exception('No puedes unificar un jugador consigo mismo.');
    }

    // 1) Pasar las ganadas/perdidas al jugador que se mantiene.
    final oldEntries = await _collections.statEntries(removePlayerId).get();
    if (oldEntries.docs.isNotEmpty) {
      final batch = _db.batch();
      final newEntriesRef = _collections.statEntries(keepPlayerId);
      for (final doc in oldEntries.docs) {
        batch.set(newEntriesRef.doc(), doc.data());
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // 2) Corregir las partidas viejas para que digan el jugador que se
    // mantiene, no el que se va a borrar.
    Future<void> fixGamesField(String field) async {
      final snap = await _collections.games
          .where(field, arrayContains: removePlayerId)
          .get();
      for (final doc in snap.docs) {
        final ids = List<String>.from(doc.data()[field] as List? ?? []);
        final updated = ids
            .map((id) => id == removePlayerId ? keepPlayerId : id)
            .toSet() // por si el jugador que se mantiene ya estaba ahí
            .toList();
        await doc.reference.update({field: updated});
      }
    }

    await fixGamesField('teamAPlayerIds');
    await fixGamesField('teamBPlayerIds');

    // 3) Corregir los ganadores de meses viejos puestos a mano.
    final overrides = await _db
        .collection('monthlyOverrides')
        .where('playerId', isEqualTo: removePlayerId)
        .get();
    for (final doc in overrides.docs) {
      await doc.reference.update({'playerId': keepPlayerId});
    }

    // 4) Borrar la ficha duplicada: ya no le queda historial propio.
    await _collections.players.doc(removePlayerId).delete();
  }

  /// Justo después de crear la cuenta, el permiso de esa sesión nueva a
  /// veces no termina de activarse a tiempo para la primera escritura en
  /// Firestore, y falla con "permission-denied" aunque la cuenta y las
  /// reglas estén bien. Se reintenta una vez, un momento después, antes
  /// de darlo por un error de verdad.
  Future<T> _withRetryOnPermissionDenied<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      await Future.delayed(const Duration(seconds: 2));
      return action();
    }
  }

  /// Mismo mensaje sin importar cuál de las dos operaciones de registro
  /// haya fallado por permiso denegado (justo después de crear la
  /// cuenta, antes de que el permiso termine de propagarse), para que
  /// la pantalla de registro no tenga que conocer detalles de Firestore.
  String _signupErrorMessage(String code) {
    return code == 'permission-denied'
        ? 'No se pudo vincular esa ficha — puede que ya esté ligada a '
              'otra cuenta. Vuelve a intentarlo o avísale al '
              'administrador.'
        : 'No se pudo completar (código: $code).';
  }

  @override
  Future<String?> createFamilyPlayerForSignup(
    String fullName, {
    String? shortName,
    required String authUid,
  }) async {
    try {
      await _withRetryOnPermissionDenied(
        () => _db.collection('players').add({
          'fullName': fullName,
          'shortName': (shortName == null || shortName.trim().isEmpty)
              ? null
              : shortName.trim(),
          'active': true,
          'authUid': authUid,
        }),
      );
      return null;
    } on FirebaseException catch (e) {
      return _signupErrorMessage(e.code);
    } catch (e) {
      return 'No se pudo completar: $e';
    }
  }

  @override
  Future<String?> linkPlayerToAuth(String playerId, String authUid) async {
    try {
      await _withRetryOnPermissionDenied(
        () => _db.collection('players').doc(playerId).update({
          'authUid': authUid,
        }),
      );
      return null;
    } on FirebaseException catch (e) {
      return _signupErrorMessage(e.code);
    } catch (e) {
      return 'No se pudo completar: $e';
    }
  }
}
