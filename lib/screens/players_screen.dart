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
      body: StreamBuilder<List<Player>>(
        stream: firestore.watchAllPlayers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final players = snapshot.data!;
          if (players.isEmpty) {
            return const Center(
              child: Text(
                'Todavía no hay jugadores. Agrega uno con el botón +.',
              ),
            );
          }
          return ListView.builder(
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
                        onPressed: () => firestore.reactivatePlayer(player.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever_outlined),
                        tooltip: 'Eliminar definitivamente',
                        onPressed: () =>
                            _confirmPermanentDelete(context, firestore, player),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddPlayerDialog(context, firestore),
        child: const Icon(Icons.add),
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
