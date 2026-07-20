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
    return _db.collectionGroup('statEntries').snapshots().map((snap) {
      return snap.docs.map((d) {
        final playerId = d.reference.parent.parent!.id;
        return PlayerStatEntryDto.fromMap(d.id, playerId, d.data());
      }).toList();
    });
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
