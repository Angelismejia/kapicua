import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

const _newPlayerSentinel = '__new__';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;
  String _selectedPlayerId = _newPlayerSentinel;

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kapicua',
                  style: TextStyle(
                    fontFamily: 'AlexBrush',
                    fontSize: 56,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSignUp ? 'Crea tu cuenta' : 'Inicia sesión',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                if (_isSignUp) ...[
                  StreamBuilder<List<Player>>(
                    stream: firestore.watchAllPlayers(),
                    builder: (context, snapshot) {
                      final unlinked = (snapshot.data ?? [])
                          .where((p) => p.authUid == null)
                          .toList();
                      if (unlinked.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedPlayerId,
                          decoration: const InputDecoration(
                            labelText: '¿Ya estás en la lista de jugadores?',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: _newPlayerSentinel,
                              child: Text('Soy nuevo, no estoy en la lista'),
                            ),
                            ...unlinked.map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text('Soy ${p.fullName}'),
                              ),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () =>
                                _selectedPlayerId = value ?? _newPlayerSentinel,
                          ),
                        ),
                      );
                    },
                  ),
                  if (_selectedPlayerId == _newPlayerSentinel)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
                TextField(
                  controller: _usernameController,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    helperText: 'Solo letras y números, sin espacios',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : () => _submit(auth),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? 'Crear cuenta' : 'Entrar'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _error = null;
                          _selectedPlayerId = _newPlayerSentinel;
                        }),
                  child: Text(
                    _isSignUp
                        ? '¿Ya tienes cuenta? Inicia sesión'
                        : '¿Nuevo en la liga? Crea tu cuenta',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AuthService auth) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final linkingExisting = _selectedPlayerId != _newPlayerSentinel;
    final error = _isSignUp
        ? await auth.signUp(
            fullName: linkingExisting ? null : _fullNameController.text,
            username: _usernameController.text,
            password: _passwordController.text,
            existingPlayerId: linkingExisting ? _selectedPlayerId : null,
          )
        : await auth.signIn(
            username: _usernameController.text,
            password: _passwordController.text,
          );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }
}
