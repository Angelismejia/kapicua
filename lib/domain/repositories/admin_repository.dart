/// Un jugador es admin si su uid tiene un documento en "admins" (además
/// del respaldo por correo fijo en las reglas de autenticación).
abstract class AdminRepository {
  Stream<Set<String>> watchAdminUids();

  Future<void> grantAdmin(String uid);

  Future<void> revokeAdmin(String uid);
}
