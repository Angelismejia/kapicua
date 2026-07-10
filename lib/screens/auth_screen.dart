import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'signup_pin_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String? _statusMessage;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Contador visible de segundos mientras carga: para saber con certeza
  // si la app sigue "viva" esperando una respuesta o si el navegador se
  // congeló por completo (si el contador también se detiene, es el
  // segundo caso).
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  void _startElapsedTimer() {
    _elapsedSeconds = 0;
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
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
                const Text(
                  'La mejor forma de registrar tus partidas de dominó.',
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                AutofillGroup(
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Correo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(auth),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            tooltip: _obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    '${_statusMessage ?? 'Un momento...'} '
                    '($_elapsedSeconds s)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _submit(auth),
                      child: const Text('Iniciar sesión'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignupPinScreen(),
                        ),
                      ),
                      child: const Text('Soy nuevo en la liga: crear cuenta'),
                    ),
                  ),
                ],
                TextButton(
                  onPressed: _loading ? null : () => _forgotPassword(auth),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : () => _playWithoutAccount(auth),
                  child: const Text('Jugar sin cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AuthService auth) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Escribe tu correo y contraseña.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = 'Conectando con el servidor...';
    });
    _startElapsedTimer();
    String? error;
    try {
      error = await auth.signIn(email, password);
      if (error == null) {
        if (mounted) {
          setState(() => _statusMessage = 'Sesión iniciada, cargando...');
        }
        try {
          TextInput.finishAutofillContext();
        } catch (_) {
          // El autofill del navegador es una ayuda extra, no debe poder
          // dejar el botón "cargando" pegado si falla.
        }
      }
    } catch (e) {
      // Red de seguridad: nada debe poder fallar en silencio. Si algo
      // no esperado se escapa de auth.signIn, se muestra tal cual en
      // vez de dejar la pantalla sin ninguna explicación.
      error = 'Error inesperado: $e';
    } finally {
      if (error != null) _stopElapsedTimer();
      if (mounted) {
        setState(() {
          _loading = error == null;
          _error = error;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _forgotPassword(AuthService auth) async {
    final controller = TextEditingController(text: _emailController.text);
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (email == null || email.trim().isEmpty || !mounted) return;

    final error = await auth.sendPasswordResetEmail(email.trim());
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Correo enviado'),
        content: const Text(
          'Te enviamos un correo para restablecer tu contraseña. Revisa '
          'tu bandeja de entrada y, si no lo ves ahí en unos minutos, '
          'revisa también la carpeta de spam o correo no deseado — a '
          'veces cae ahí.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _playWithoutAccount(AuthService auth) async {
    setState(() => _loading = true);
    final error = await auth.playWithoutAccount();
    if (!mounted) return;
    if (error != null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
    // Si no hubo error, la pantalla se reemplaza sola (main.dart detecta
    // la sesión anónima nueva), así que no hace falta apagar _loading.
  }
}
