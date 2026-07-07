import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_service.dart';
import '../services/theme_controller.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final adminService = context.watch<AdminService>();

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
            child: adminService.isAdmin
                ? ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: const Text('Modo administrador activo'),
                    subtitle: const Text(
                      'Puedes gestionar jugadores y estadísticas.',
                    ),
                    trailing: TextButton(
                      onPressed: () => adminService.lock(),
                      child: const Text('Salir'),
                    ),
                  )
                : ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Modo administrador'),
                    subtitle: const Text(
                      'Solo para quienes administran la liga.',
                    ),
                    trailing: TextButton(
                      onPressed: () => _showUnlockDialog(context, adminService),
                      child: const Text('Ingresar'),
                    ),
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

  void _showUnlockDialog(BuildContext context, AdminService adminService) {
    final pinController = TextEditingController();
    var wrongPin = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Modo administrador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: pinController,
                autofocus: true,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  errorText: wrongPin ? 'PIN incorrecto' : null,
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
              onPressed: () async {
                final ok = await adminService.unlock(pinController.text);
                if (ok) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } else {
                  setState(() => wrongPin = true);
                }
              },
              child: const Text('Entrar'),
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
