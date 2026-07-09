import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'auth_screen.dart';
import 'complete_profile_screen.dart';
import 'main_shell.dart';

/// Se pasa en tiempo de compilación (--dart-define=FAMILY_PIN=...) para
/// que no quede escrito en el código ni en git.
const String kFamilyPin = String.fromEnvironment(
  'FAMILY_PIN',
  defaultValue: '0000',
);

class FamilyGateScreen extends StatefulWidget {
  const FamilyGateScreen({super.key});

  @override
  State<FamilyGateScreen> createState() => _FamilyGateScreenState();
}

class _FamilyGateScreenState extends State<FamilyGateScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kapicua',
                  style: TextStyle(
                    fontFamily: 'AlexBrush',
                    fontSize: 48,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '¿Eres parte de la familia?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Escribe el PIN para entrar a la liga con certificados y estadísticas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'PIN familiar',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submitPin,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : _continueAsGuest,
                  child: const Text('No, solo quiero jugar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitPin() {
    if (_pinController.text.trim() != kFamilyPin) {
      setState(() => _error = 'PIN incorrecto.');
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
    );
  }

  Future<void> _continueAsGuest() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final firestore = context.read<FirestoreService>();
      await firestore.createGuestProfile(uid);
      firestore.isGuest = true;
      firestore.guestUid = uid;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo continuar: $e')));
    }
  }
}
