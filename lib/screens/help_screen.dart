import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/theme_controller.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final auth = context.watch<AuthService>();
    final username = auth.currentUser?.email?.split('@').first ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración y ayuda')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('Modo oscuro'),
              value: themeController.isDarkMode,
              onChanged: (value) => themeController.setDarkMode(value),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    auth.isAdmin ? Icons.admin_panel_settings : Icons.person,
                  ),
                  title: Text('Sesión: $username'),
                  subtitle: Text(
                    auth.isAdmin
                        ? 'Puedes editar estadísticas.'
                        : 'Cuenta de jugador.',
                  ),
                  trailing: TextButton(
                    onPressed: () => auth.signOut(),
                    child: const Text('Cerrar sesión'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Cambiar contraseña'),
                  trailing: TextButton(
                    onPressed: () => _showChangePasswordDialog(context, auth),
                    child: const Text('Cambiar'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¿Cómo funciona Kapicua?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const _HelpStep(
            icon: Icons.people,
            title: 'Jugadores',
            description:
                'Agrega a todos los participantes de tu liga de dominó. '
                'Puedes eliminar a alguien más adelante sin perder su historial.',
          ),
          const _HelpStep(
            icon: Icons.add_circle,
            title: 'Nueva partida',
            description:
                'Arma el equipo Casa y el equipo Visita (1 o 2 jugadores cada uno) '
                'y elige la meta de puntos. Al iniciar, se abre el anotador de esa partida.',
          ),
          const _HelpStep(
            icon: Icons.scoreboard,
            title: 'Agregar ronda',
            description:
                'Después de cada mano, indica qué equipo ganó la ronda y sus puntos. '
                'La app suma el total automáticamente y detecta cuando un equipo llega a la meta.',
          ),
          const _HelpStep(
            icon: Icons.history,
            title: 'Historial',
            description:
                'Consulta todas las partidas ya terminadas y el detalle ronda por ronda.',
          ),
          const _HelpStep(
            icon: Icons.emoji_events,
            title: 'Estadísticas',
            description:
                'Ganadas, perdidas, total y porcentaje de cada jugador, llevado a mano por '
                'el administrador — no depende de las partidas anotadas arriba.',
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, AuthService auth) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    String? error;
    var loading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña nueva',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      setState(() => loading = true);
                      final result = await auth.changePassword(
                        currentPassword: currentController.text,
                        newPassword: newController.text,
                      );
                      if (result == null) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } else {
                        setState(() {
                          loading = false;
                          error = result;
                        });
                      }
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HelpStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
