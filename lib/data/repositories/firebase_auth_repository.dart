import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

AppUser _toAppUser(User user) => AppUser(
  uid: user.uid,
  email: user.email,
  displayName: user.displayName,
  isAnonymous: user.isAnonymous,
  creationTime: user.metadata.creationTime,
);

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Tiempo máximo de espera para cualquier llamada a Firebase Auth. Sin
  /// esto, una conexión lenta o caída deja el botón "cargando" pegado
  /// para siempre porque el Future nunca se resuelve por sí solo.
  static const _authTimeout = Duration(seconds: 10);

  FirebaseAuthRepository() {
    if (kIsWeb) {
      _auth.setPersistence(Persistence.LOCAL);
    }
  }

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().map((user) => user == null ? null : _toAppUser(user));
  }

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  Future<void> signOut() => _auth.signOut();
}
