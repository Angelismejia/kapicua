import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/admin_access.dart';

/// Maneja el estado reactivo de la sesión (usuario actual, si es admin)
/// para que las pantallas lo consuman con Provider, igual que antes hacía
/// `AuthService`. La comunicación con Firebase vive en [AuthRepository]
/// y [AdminRepository]; este controller solo combina ese estado.
class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;
  final AdminRepository _adminRepository;

  bool _isDynamicAdmin = false;
  StreamSubscription<Set<String>>? _adminSub;

  AuthController(this._authRepository, this._adminRepository) {
    _authRepository.authStateChanges().listen((user) {
      _adminSub?.cancel();
      _isDynamicAdmin = false;
      if (user != null) {
        _adminSub = _adminRepository.watchAdminUids().listen((admins) {
          _isDynamicAdmin = admins.contains(user.uid);
          notifyListeners();
        });
      }
      notifyListeners();
    });
  }

  AppUser? get currentUser => _authRepository.currentUser;

  bool get isSignedIn => _authRepository.isSignedIn;

  bool get isAdmin {
    if (isPermanentAdminEmail(currentUser?.email)) return true;
    return _isDynamicAdmin;
  }

  @override
  void dispose() {
    _adminSub?.cancel();
    super.dispose();
  }

  Future<String?> signUp(String email, String password) =>
      _authRepository.signUp(email, password);

  Future<String?> signIn(String email, String password) =>
      _authRepository.signIn(email, password);

  Future<String?> sendPasswordResetEmail(String email) =>
      _authRepository.sendPasswordResetEmail(email);

  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) => _authRepository.changePassword(currentPassword, newPassword);

  Future<String?> playWithoutAccount() => _authRepository.playWithoutAccount();

  Future<void> signOut() => _authRepository.signOut();
}
