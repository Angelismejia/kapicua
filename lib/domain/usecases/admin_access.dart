/// Correos con permisos de administrador (pueden editar estadísticas).
/// Se mantiene como respaldo fijo además de la colección "admins" en
/// Firestore, para que estas dos cuentas nunca puedan quedarse sin acceso.
const Set<String> kAdminEmails = {
  'angelismejia06@gmail.com',
  'proniw83@gmail.com',
  'angelmejia0183@gmail.com',
};

bool isPermanentAdminEmail(String? email) {
  final normalized = email?.trim().toLowerCase();
  return normalized != null && kAdminEmails.contains(normalized);
}
