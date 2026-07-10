import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Correos con permisos de administrador (pueden editar estadisticas).
/// Se mantiene como respaldo fijo ademas de la coleccion "admins" en
/// Firestore, para que estas dos cuentas nunca puedan quedarse sin acceso.
const Set<String> kAdminEmails = {
  'angelismejia06@gmail.com',
  'proniw83@gmail.com',
};

/// Maneja el inicio de sesion con correo y contrasena. Cada cuenta se
/// vincula a un jugador de la liga (nuevo o ya existente) por authUid.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isDynamicAdmin = false;
  StreamSubscription<DocumentSnapshot>? _adminSub;

  AuthService() {
    if (kIsWeb) {
      _auth.setPersistence(Persistence.LOCAL);
    }
    _auth.authStateChanges().listen((user) {
      _adminSub?.cancel();
      _isDynamicAdmin = false;
      if (user != null) {
        _adminSub = FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .snapshots()
            .listen((snap) {
              _isDynamicAdmin = snap.exists;
              notifyListeners();
            });
      }
      notifyListeners();
    });
  }

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => _auth.currentUser != null;

  bool get isAdmin {
    final email = _auth.currentUser?.email?.trim().toLowerCase();
    if (email != null && kAdminEmails.contains(email)) return true;
    return _isDynamicAdmin;
  }

  @override
  void dispose() {
    _adminSub?.cancel();
    super.dispose();
  }

  /// Tiempo máximo de espera para cualquier llamada a Firebase Auth. Sin
  /// esto, una conexión lenta o caída deja el botón "cargando" pegado
  /// para siempre porque el Future nunca se resuelve por sí solo.
  static const _authTimeout = Duration(seconds: 10);

  Future<String?> signUp(String email, String password) async {
    try {
      await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(_authTimeout);
      return null;
    } on TimeoutException {
      return 'Tardó demasiado en responder. Revisa tu conexión e intenta de nuevo.';
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      return 'No se pudo crear la cuenta: $e';
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth
          .signInWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(_authTimeout);
      return null;
    } on TimeoutException {
      return 'Tardó demasiado en responder. Revisa tu conexión e intenta de nuevo.';
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      return 'No se pudo iniciar sesión: $e';
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth
          .sendPasswordResetEmail(
            email: email.trim(),
            actionCodeSettings: ActionCodeSettings(
              url: 'https://kapicua.web.app',
            ),
          )
          .timeout(_authTimeout);
      return null;
    } on TimeoutException {
      return 'Tardó demasiado en responder. Revisa tu conexión e intenta de nuevo.';
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
      await user.reauthenticateWithCredential(credential).timeout(_authTimeout);
      await user.updatePassword(newPassword).timeout(_authTimeout);
      return null;
    } on TimeoutException {
      return 'Tardó demasiado en responder. Revisa tu conexión e intenta de nuevo.';
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      return 'No se pudo cambiar la contraseña: $e';
    }
  }

  /// Para jugar sin ninguna cuenta: no pide nada, entra directo como
  /// invitado (sus partidas no se sincronizan con otro dispositivo).
  Future<String?> playWithoutAccount() async {
    try {
      await _auth.signInAnonymously().timeout(_authTimeout);
      return null;
    } on TimeoutException {
      return 'Tardó demasiado en responder. Revisa tu conexión e intenta de nuevo.';
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (e) {
      return 'No se pudo continuar: $e';
    }
  }

  Future<void> signOut() => _auth.signOut();
}
