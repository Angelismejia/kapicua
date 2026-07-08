import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../services/firestore_service.dart';
import '../widgets/add_player_dialog.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Jugadores')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: _AddPlayerCard(
              onAdd: () => showAddPlayerDialog(context, firestore),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Player>>(
              stream: firestore.watchAllPlayers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final players = snapshot.data!;
                if (players.isEmpty) {
                  return const Center(
                    child: Text('Todavía no hay jugadores en la liga.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    return ListTile(
                      title: Text(player.displayName),
                      subtitle: Text(
                        [
                          if (player.shortName != null &&
                              player.shortName!.isNotEmpty)
                            player.fullName,
                          if (!player.active) 'Inactivo',
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar',
                            onPressed: () =>
                                _showEditDialog(context, firestore, player),
                          ),
                          if (player.active)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Eliminar',
                              onPressed: () =>
                                  _confirmRemove(context, firestore, player),
                            )
                          else ...[
                            IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: 'Reactivar',
                              onPressed: () =>
                                  firestore.reactivatePlayer(player.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_outlined),
                              tooltip: 'Eliminar definitivamente',
                              onPressed: () => _confirmPermanentDelete(
                                context,
                                firestore,
                                player,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    FirestoreService firestore,
    Player player,
  ) {
    final fullNameController = TextEditingController(text: player.fullName);
    final shortNameController = TextEditingController(
      text: player.shortName ?? '',
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar jugador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fullNameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: shortNameController,
              decoration: const InputDecoration(
                labelText: 'Apodo o nombre corto (opcional)',
                helperText: 'Así aparecerá en las listas y partidas',
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
            onPressed: () {
              final fullName = fullNameController.text.trim();
              if (fullName.isNotEmpty) {
                firestore.updatePlayer(
                  player.id,
                  fullName,
                  shortName: shortNameController.text,
                );
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmPermanentDelete(
    BuildContext context,
    FirestoreService firestore,
    Player player,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar definitivamente'),
        content: Text(
          '¿Borrar a ${player.displayName} para siempre? Su nombre ya no podrá mostrarse '
          'en partidas o certificados antiguos donde haya participado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              firestore.deletePlayerPermanently(player.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('Eliminar para siempre'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(
    BuildContext context,
    FirestoreService firestore,
    Player player,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar jugador'),
        content: Text(
          '¿Quitar a ${player.displayName} de la lista de jugadores activos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              firestore.removePlayer(player.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _AddPlayerCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddPlayerCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(Icons.groups_rounded, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jugadores de la liga',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Agrega un nuevo participante aquí.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Agregar',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
