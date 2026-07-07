import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'auth_screen.dart';
import 'main_shell.dart';

const _newPlayerSentinel = '__new__';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  String _selectedPlayerId = _newPlayerSentinel;
  bool _loading = false;
  late final TextEditingController _fullNameController;
  final _shortNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool get _needsAccount => FirebaseAuth.instance.currentUser == null;

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
                '¡Ya casi! Solo falta ubicarte en la liga.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              StreamBuilder<List<Player>>(
                stream: firestore.watchAllPlayers(),
                builder: (context, snapshot) {
                  final unlinked = (snapshot.data ?? [])
                      .where((p) => p.authUid == null)
                      .toList();
                  return DropdownButtonFormField<String>(
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
                      () => _selectedPlayerId = value ?? _newPlayerSentinel,
                    ),
                  );
                },
              ),
              if (_selectedPlayerId == _newPlayerSentinel) ...[
                const SizedBox(height: 12),
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
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
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

    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (email.isEmpty || password.isEmpty) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escribe tu correo y contraseña.')),
        );
        return;
      }
      final error = await auth.signUp(email, password);
      if (error != null) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      uid = FirebaseAuth.instance.currentUser!.uid;
    }

    if (_selectedPlayerId == _newPlayerSentinel) {
      final fullName = _fullNameController.text.trim();
      if (fullName.isEmpty) {
        setState(() => _loading = false);
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
          .doc(_selectedPlayerId)
          .update({'authUid': uid});
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }
}
