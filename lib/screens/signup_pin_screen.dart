import 'package:flutter/material.dart';

import 'auth_screen.dart';
import 'family_gate_screen.dart' show kFamilyPin;
import 'select_player_screen.dart';

/// Primer paso para registrarse: hay que saber el PIN familiar antes de
/// poder crear una cuenta nueva.
class SignupPinScreen extends StatefulWidget {
  const SignupPinScreen({super.key});

  @override
  State<SignupPinScreen> createState() => _SignupPinScreenState();
}

class _SignupPinScreenState extends State<SignupPinScreen> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
              (route) => false,
            ),
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
                  'Escribe el PIN para registrarte en la liga.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitPin(),
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
                    onPressed: _submitPin,
                    child: const Text('Confirmar'),
                  ),
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectPlayerScreen()),
    );
  }
}
