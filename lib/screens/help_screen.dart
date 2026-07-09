import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/theme_controller.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _confirmClearHistory(
    BuildContext context,
    FirestoreService firestore,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar historial de partidas'),
        content: const Text(
          'Esto borra TODAS las partidas (terminadas y en curso) y sus '
          'rondas para siempre. No se puede deshacer. Las estadísticas '
          '(ganadas/perdidas) no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await firestore.clearGameHistory();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Historial de partidas borrado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final isAdmin = context.watch<AuthService>().isAdmin;
    final firestore = context.read<FirestoreService>();

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
          if (isAdmin) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Borrar historial de partidas'),
                subtitle: const Text(
                  'Útil para quitar partidas de prueba antes de usar la '
                  'app de verdad.',
                ),
                onTap: () => _confirmClearHistory(context, firestore),
              ),
            ),
          ],
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
                'Después de cada mano, toca el "+" del equipo que anotó y escribe sus '
                'puntos (o "Para ambos" si los dos anotaron igual). La app suma el total '
                'automáticamente y detecta cuando un equipo llega a la meta.',
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
                'el administrador — no depende de las partidas anotadas arriba. Toca el '
                'ícono de compartir arriba para mandar una imagen de la tabla por WhatsApp.',
          ),
          const _HelpStep(
            icon: Icons.workspace_premium_outlined,
            title: 'Certificados',
            description:
                'Cada mes se le hace un certificado a quien va ganando. Ábrelo y toca '
                '"Compartir" para mandarlo por WhatsApp, o "Descargar" para guardarlo.',
          ),
          const _HelpStep(
            icon: Icons.account_circle_outlined,
            title: 'Tu perfil',
            description:
                'Desde el ícono de tu foto en Inicio puedes cambiar tu foto de perfil '
                'y tu contraseña.',
          ),
          if (isAdmin)
            const _HelpStep(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Permisos de administrador',
              description:
                  'Desde tu perfil puedes dar o quitar permisos de administrador a otros '
                  'jugadores que ya tengan cuenta creada.',
            ),
        ],
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
