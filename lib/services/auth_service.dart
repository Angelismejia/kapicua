import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Correos con permisos de administrador (pueden editar estadisticas).
const Set<String> kAdminEmails = {
  'angelismejia06@gmail.com',
  'proniw83@gmail.com',
};

/// Maneja el inicio de sesion con correo y contrasena. Cada cuenta se
/// vincula a un jugador de la liga (nuevo o ya existente) por authUid.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthService() {
    if (kIsWeb) {
      _auth.setPersistence(Persistence.LOCAL);
    }
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => _auth.currentUser != null;

  bool get isAdmin {
    final email = _auth.currentUser?.email?.trim().toLowerCase();
    if (email == null) return false;
    return kAdminEmails.contains(email);
  }

  Future<String?> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      return 'No se pudo crear la cuenta: $e';
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      return 'No se pudo iniciar sesión: $e';
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: ActionCodeSettings(url: 'https://kapicua.web.app'),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      return 'No se pudo enviar el correo: $e';
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ese correo ya tiene una cuenta. Intenta iniciar sesión.';
      case 'invalid-email':
        return 'Correo inválido.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'operation-not-allowed':
        return 'El inicio de sesión con correo y contraseña no está '
            'activado en Firebase todavía.';
      default:
        return 'No se pudo completar (código: $code).';
    }
  }

  /// Cambia la contraseña de la cuenta actual. Requiere la contraseña
  /// actual porque Firebase exige un inicio de sesión reciente para
  /// operaciones sensibles como esta.
  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      return 'No se pudo identificar la cuenta.';
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      return 'No se pudo cambiar la contraseña: $e';
    }
  }

  /// Para jugar sin ninguna cuenta: no pide nada, entra directo como
  /// invitado (sus partidas no se sincronizan con otro dispositivo).
  Future<void> playWithoutAccount() async {
    await _auth.signInAnonymously();
  }

  Future<void> signOut() => _auth.signOut();
}
