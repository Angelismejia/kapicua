import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Correos con permisos de administrador (pueden editar estadisticas).
const Set<String> kAdminEmails = {
  'angelismejia06@gmail.com',
  'proniw83@gmail.com',
};

/// Maneja el inicio de sesion con Google. Cada cuenta se vincula a un
/// jugador de la liga (nuevo o ya existente) por authUid.
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

  Future<String?> signInWithGoogle() async {
    if (!kIsWeb) {
      return 'El inicio de sesión con Google solo está disponible en la versión web por ahora.';
    }
    try {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return null;
      }
      return 'No se pudo iniciar sesión (${e.code}).';
    }
  }

  /// Para jugar sin ninguna cuenta: no pide nada, entra directo como
  /// invitado (sus partidas no se sincronizan con otro dispositivo).
  Future<void> playWithoutAccount() async {
    await _auth.signInAnonymously();
  }

  Future<void> signOut() => _auth.signOut();
}
