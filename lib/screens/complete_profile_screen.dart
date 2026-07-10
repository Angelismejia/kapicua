import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'auth_screen.dart';
import 'main_shell.dart';

class CompleteProfileScreen extends StatefulWidget {
  /// Jugador elegido en la pantalla anterior (SelectPlayerScreen), o
  /// null si dijo que era nuevo. Ya viene decidido, así que aquí no se
  /// vuelve a preguntar.
  final String? selectedPlayerId;

  const CompleteProfileScreen({super.key, required this.selectedPlayerId});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  bool _loading = false;
  bool _obscurePassword = true;
  late final TextEditingController _fullNameController;
  final _shortNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool get _needsAccount => FirebaseAuth.instance.currentUser == null;
  bool get _isNewPlayer => widget.selectedPlayerId == null;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _fullNameController = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _shortNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completa tu perfil'),
        actions: [
          TextButton(
            onPressed: () async {
              if (_needsAccount) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
                return;
              }
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isNewPlayer
                    ? '¡Ya casi! Escribe tu nombre para crear tu ficha.'
                    : '¡Ya casi! Solo falta crear tu acceso.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_isNewPlayer) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _shortNameController,
                  decoration: const InputDecoration(
                    labelText: 'Apodo o nombre corto (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_needsAccount) ...[
                const SizedBox(height: 20),
                Text(
                  'Crea tu acceso',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Asegúrate de escribir correctamente tu correo '
                          'electrónico. Si algún día olvidas tu contraseña, '
                          'enviaremos el enlace de recuperación a ese '
                          'correo. Si está mal escrito, no podrás recibir '
                          'el mensaje y podrías perder el acceso a tu '
                          'cuenta.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AutofillGroup(
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.newUsername],
                        decoration: const InputDecoration(
                          labelText: 'Correo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
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
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : () => _submit(auth, firestore),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continuar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AuthService auth, FirestoreService firestore) async {
    setState(() => _loading = true);

    try {
      var uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        if (email.isEmpty || password.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Escribe tu correo y contraseña.')),
          );
          return;
        }
        final error = await auth.signUp(email, password);
        if (error != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
          return;
        }
        uid = FirebaseAuth.instance.currentUser!.uid;
        try {
          TextInput.finishAutofillContext();
        } catch (_) {
          // El autofill del navegador es una ayuda extra, no debe poder
          // dejar el flujo de registro pegado si falla.
        }
      }

      if (_isNewPlayer) {
        final fullName = _fullNameController.text.trim();
        if (fullName.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Escribe tu nombre completo.')),
          );
          return;
        }
        await FirebaseFirestore.instance.collection('players').add({
          'fullName': fullName,
          'shortName': _shortNameController.text.trim().isEmpty
              ? null
              : _shortNameController.text.trim(),
          'active': true,
          'authUid': uid,
        });
      } else {
        await FirebaseFirestore.instance
            .collection('players')
            .doc(widget.selectedPlayerId)
            .update({'authUid': uid});
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo completar: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
