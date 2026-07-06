import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../services/firestore_service.dart';

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
            return const Center(child: Text('Todavía no hay jugadores. Agrega uno con el botón +.'));
          }
          return ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final player = players[index];
              return ListTile(
                title: Text(player.displayName),
                subtitle: Text([
                  if (player.shortName != null && player.shortName!.isNotEmpty) player.fullName,
                  if (!player.active) 'Inactivo',
                ].join(' · ')),
                trailing: player.active
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmRemove(context, firestore, player),
                      )
                    : IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: 'Reactivar',
                        onPressed: () => firestore.reactivatePlayer(player.id),
                      ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, firestore),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, FirestoreService firestore) {
    final fullNameController = TextEditingController();
    final shortNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo jugador'),
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
                firestore.addPlayer(fullName, shortName: shortNameController.text);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, FirestoreService firestore, Player player) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar jugador'),
        content: Text('¿Quitar a ${player.displayName} de la lista de jugadores activos?'),
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
