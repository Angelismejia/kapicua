import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/admin_repository.dart';

class FirestoreAdminRepository implements AdminRepository {
  final FirebaseFirestore _db;

  FirestoreAdminRepository(this._db);

  @override
  Stream<Set<String>> watchAdminUids() {
    return _db
        .collection('admins')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  @override
  Future<void> grantAdmin(String uid) async {
    await _db.collection('admins').doc(uid).set({
      'grantedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<void> revokeAdmin(String uid) async {
    await _db.collection('admins').doc(uid).delete();
  }
}
