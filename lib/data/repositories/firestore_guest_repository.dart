import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/guest_repository.dart';

class FirestoreGuestRepository implements GuestRepository {
  final FirebaseFirestore _db;

  FirestoreGuestRepository(this._db);

  @override
  Future<bool> hasGuestProfile(String uid) async {
    final doc = await _db.collection('guestSpaces').doc(uid).get();
    return doc.exists;
  }

  @override
  Future<void> createGuestProfile(String uid) async {
    await _db.collection('guestSpaces').doc(uid).set({
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
