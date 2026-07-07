import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Usuarios (normalizados) que tienen permisos de administrador.
const Set<String> kAdminUsernames = {'andy', 'blady'};

String normalizeUsername(String username) {
  final trimmed = username.trim().toLowerCase();
  return trimmed.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _emailForUsername(String username) =>
    '${normalizeUsername(username)}@kapicua.local';

/// Maneja el inicio de sesion y registro de todos los jugadores.
/// Cada cuenta (nombre + usuario + contraseña) crea tambien su
/// jugador correspondiente en la liga, vinculado por authUid.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthService() {
    if (kIsWeb) {
      _auth.setPersistence(Persistence.LOCAL);
    }
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => _auth.currentUser != null;

  bool get isAdmin {
    final email = _auth.currentUser?.email;
    if (email == null) return false;
    return kAdminUsernames.contains(email.split('@').first);
  }

  /// Si [existingPlayerId] viene dado, la cuenta nueva se vincula a ese
  /// jugador ya existente en vez de crear uno duplicado.
  Future<String?> signUp({
    String? fullName,
    required String username,
    required String password,
    String? existingPlayerId,
  }) async {
    final normalized = normalizeUsername(username);
    if (existingPlayerId == null &&
        (fullName == null || fullName.trim().isEmpty)) {
      return 'Escribe tu nombre completo.';
    }
    if (normalized.isEmpty) return 'Elige un usuario válido.';

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _emailForUsername(username),
        password: password,
      );
      if (existingPlayerId != null) {
        await _db.collection('players').doc(existingPlayerId).update({
          'authUid': credential.user!.uid,
          'shortName': normalized,
        });
      } else {
        await _db.collection('players').add({
          'fullName': fullName!.trim(),
          'shortName': normalized,
          'active': true,
          'authUid': credential.user!.uid,
        });
      }
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Ese usuario ya existe, elige otro.';
        case 'weak-password':
          return 'La contraseña debe tener al menos 6 caracteres.';
        default:
          return 'No se pudo crear la cuenta (${e.code}).';
      }
    }
  }

  Future<String?> signIn({
    required String username,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailForUsername(username),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Usuario o contraseña incorrectos.';
        default:
          return 'No se pudo iniciar sesión (${e.code}).';
      }
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return 'No hay sesión activa.';
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Tu contraseña actual no es correcta.';
        case 'weak-password':
          return 'La nueva contraseña debe tener al menos 6 caracteres.';
        default:
          return 'No se pudo cambiar la contraseña (${e.code}).';
      }
    }
  }
}
