import '../entities/app_user.dart';

/// Inicio de sesión con correo y contraseña (o anónimo para "jugar sin
/// cuenta"). Todos los métodos de acción devuelven un mensaje de error
/// en español listo para mostrar, o `null` si todo salió bien.
abstract class AuthRepository {
  AppUser? get currentUser;

  bool get isSignedIn;

  Stream<AppUser?> authStateChanges();

  Future<String?> signUp(String email, String password);

  Future<String?> signIn(String email, String password);

  Future<String?> sendPasswordResetEmail(String email);

  /// Requiere la contraseña actual porque Firebase exige un inicio de
  /// sesión reciente para operaciones sensibles como esta.
  Future<String?> changePassword(String currentPassword, String newPassword);

  /// Para jugar sin ninguna cuenta: no pide nada, entra directo como
  /// invitado (sus partidas no se sincronizan con otro dispositivo).
  Future<String?> playWithoutAccount();

  Future<void> signOut();
}
