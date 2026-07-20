import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/guest_session.dart';

/// Resuelve las colecciones de Firestore según el espacio actual
/// (familia o invitado). Compartido por los repositorios que necesitan
/// más de una colección, para que todos calculen la ruta de la misma
/// forma exacta.
class FirestoreCollections {
  final FirebaseFirestore db;
  final GuestSession session;

  FirestoreCollections(this.db, this.session);

  CollectionReference<Map<String, dynamic>> get players => session.isGuest
      ? db
            .collection('guestSpaces')
            .doc(session.guestUid)
            .collection('players')
      : db.collection('players');

  CollectionReference<Map<String, dynamic>> get games => session.isGuest
      ? db.collection('guestSpaces').doc(session.guestUid).collection('games')
      : db.collection('games');

  CollectionReference<Map<String, dynamic>> statEntries(String playerId) =>
      players.doc(playerId).collection('statEntries');
}
