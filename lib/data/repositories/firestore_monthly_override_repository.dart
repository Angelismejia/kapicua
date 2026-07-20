import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/monthly_override_repository.dart';

class FirestoreMonthlyOverrideRepository implements MonthlyOverrideRepository {
  final FirebaseFirestore _db;

  FirestoreMonthlyOverrideRepository(this._db);

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  @override
  Stream<Map<String, dynamic>?> watchMonthlyOverride(DateTime month) {
    return _db
        .collection('monthlyOverrides')
        .doc(_monthKey(month))
        .snapshots()
        .map((doc) => doc.data());
  }

  @override
  Stream<Map<String, Map<String, dynamic>>> watchAllMonthlyOverrides() {
    return _db
        .collection('monthlyOverrides')
        .snapshots()
        .map((snap) => {for (final d in snap.docs) d.id: d.data()});
  }

  @override
  Future<void> setMonthlyOverride(
    DateTime month,
    String playerId,
    int wins,
    int losses,
  ) async {
    await _db.collection('monthlyOverrides').doc(_monthKey(month)).set({
      'playerId': playerId,
      'wins': wins,
      'losses': losses,
    });
  }

  @override
  Future<void> clearMonthlyOverride(DateTime month) async {
    await _db.collection('monthlyOverrides').doc(_monthKey(month)).delete();
  }
}
