/// Representa a la persona con sesión iniciada, sin depender de
/// `firebase_auth` (eso queda en la capa de datos).
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isAnonymous;
  final DateTime? creationTime;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isAnonymous,
    required this.creationTime,
  });
}
