import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/guest_session.dart';
import '../../domain/entities/player_stat_entry.dart';
import '../../domain/repositories/stats_repository.dart';
import '../models/player_stat_entry_dto.dart';
import 'firestore_collections.dart';

class FirestoreStatsRepository implements StatsRepository {
  final FirebaseFirestore _db;
  final FirestoreCollections _collections;

  FirestoreStatsRepository(FirebaseFirestore db, GuestSession session)
    : _db = db,
      _collections = FirestoreCollections(db, session);

  @override
  Stream<List<PlayerStatEntry>> watchPlayerStatEntries(String playerId) {
    return _collections
        .statEntries(playerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PlayerStatEntryDto.fromMap(d.id, playerId, d.data()))
              .toList(),
        );
  }

  @override
  Stream<List<PlayerStatEntry>> watchAllStatEntries() {
    if (_collections.session.isGuest) return _watchGuestStatEntries();
    return _db.collectionGroup('statEntries').snapshots().map((snap) {
      return snap.docs
          // La consulta "collection group" busca en TODA la base, así
          // que también trae lo de los espacios de invitados — eso no
          // es parte de la liga de la familia.
          .where((d) => !d.reference.path.startsWith('guestSpaces/'))
          .map((d) {
            final playerId = d.reference.parent.parent!.id;
            return PlayerStatEntryDto.fromMap(d.id, playerId, d.data());
          })
          .toList();
    });
  }

  /// Un invitado no puede usar la consulta "collection group" (esa trae
  /// las ganadas/perdidas de toda la familia y de todos los demás
  /// invitados: lento, y además son datos que no le tocan ver). En su
  /// lugar escucha la subcolección de cada uno de sus propios jugadores
  /// y las junta en una sola lista. Siempre entrega algo (aunque sea una
  /// lista vacía) apenas carga, para que Inicio no se quede esperando
  /// cuando el invitado todavía no tiene jugadores.
  Stream<List<PlayerStatEntry>> _watchGuestStatEntries() {
    final entriesByPlayer = <String, List<PlayerStatEntry>>{};
    final entrySubs = <String, StreamSubscription<List<PlayerStatEntry>>>{};
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? playersSub;
    late final StreamController<List<PlayerStatEntry>> controller;

    void emit() {
      // Solo cuando ya respondieron todos los jugadores, para no mostrar
      // por un instante estadísticas a medias.
      if (entriesByPlayer.length != entrySubs.length) return;
      controller.add([for (final list in entriesByPlayer.values) ...list]);
    }

    controller = StreamController<List<PlayerStatEntry>>(
      onListen: () {
        playersSub = _collections.players.snapshots().listen((snap) {
          final ids = snap.docs.map((d) => d.id).toSet();
          for (final id in entrySubs.keys.toList()) {
            if (ids.contains(id)) continue;
            entrySubs.remove(id)!.cancel();
            entriesByPlayer.remove(id);
          }
          for (final id in ids) {
            entrySubs.putIfAbsent(
              id,
              () => watchPlayerStatEntries(id).listen((entries) {
                entriesByPlayer[id] = entries;
                emit();
              }, onError: controller.addError),
            );
          }
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await playersSub?.cancel();
        for (final sub in entrySubs.values) {
          await sub.cancel();
        }
        entrySubs.clear();
        entriesByPlayer.clear();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> addPlayerStatEntry(String playerId, bool isWin) async {
    await _collections
        .statEntries(playerId)
        .add({'isWin': isWin, 'createdAt': Timestamp.fromDate(DateTime.now())});
  }

  @override
  Future<void> addPlayerStatEntries(
    String playerId,
    bool isWin,
    int count, {
    DateTime? date,
  }) async {
    final batch = _db.batch();
    final timestamp = Timestamp.fromDate(date ?? DateTime.now());
    final collection = _collections.statEntries(playerId);
    for (var i = 0; i < count; i++) {
      batch.set(collection.doc(), {'isWin': isWin, 'createdAt': timestamp});
    }
    await batch.commit();
  }

  @override
  Future<void> deletePlayerStatEntry(String playerId, String entryId) async {
    await _collections.statEntries(playerId).doc(entryId).delete();
  }

  @override
  Future<void> deletePlayerStatEntries(
    String playerId,
    List<String> entryIds,
  ) async {
    final batch = _db.batch();
    final collection = _collections.statEntries(playerId);
    for (final id in entryIds) {
      batch.delete(collection.doc(id));
    }
    await batch.commit();
  }

  @override
  Future<void> updatePlayerStatEntryDate(
    String playerId,
    String entryId,
    DateTime newDate,
  ) async {
    await _collections
        .statEntries(playerId)
        .doc(entryId)
        .update({'createdAt': Timestamp.fromDate(newDate)});
  }
}
