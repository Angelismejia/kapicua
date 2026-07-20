import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/guest_session.dart';
import '../../domain/entities/player.dart';
import '../../domain/repositories/player_repository.dart';
import '../../domain/usecases/delete_player_permanently_usecase.dart';
import '../../domain/usecases/merge_players_usecase.dart';
import '../controllers/auth_controller.dart';
import '../widgets/add_player_dialog.dart';
import '../widgets/merge_players_dialog.dart';
import '../widgets/photo_viewer.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final players = context.read<PlayerRepository>();
    final isGuest = context.read<GuestSession>().isGuest;
    // Un invitado no es "administrador", pero su espacio es privado y
    // solo suyo — nadie más lo comparte, así que puede manejarlo
    // libremente igual que un admin maneja la liga de la familia.
    final canManage = context.watch<AuthController>().isAdmin || isGuest;

    return StreamBuilder<List<Player>>(
      stream: players.watchAllPlayers(),
      builder: (context, snapshot) {
        final playerList = snapshot.data ?? [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Jugadores'),
            actions: [
              if (canManage && playerList.length >= 2)
                IconButton(
                  icon: const Icon(Icons.merge_type_rounded),
                  tooltip: 'Unificar jugadores duplicados',
                  onPressed: () => showMergePlayersDialog(
                    context,
                    context.read<MergePlayersUseCase>(),
                    playerList,
                  ),
                ),
            ],
          ),
          body: !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    _AddPlayerCard(
                      onAdd: () => showAddPlayerDialog(context, players),
                    ),
                    const SizedBox(height: 12),
                    if (playerList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Todavía no hay jugadores en la liga.'),
                        ),
                      )
                    else ...[
                      ...playerList
                          .where((p) => p.active)
                          .map(
                            (player) => _playerTile(
                              context,
                              players,
                              canManage,
                              player,
                            ),
                          ),
                      if (playerList.any((p) => !p.active))
                        Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              'Jugadores inactivos '
                              '(${playerList.where((p) => !p.active).length})',
                            ),
                            children: playerList
                                .where((p) => !p.active)
                                .map(
                                  (player) => _playerTile(
                                    context,
                                    players,
                                    canManage,
                                    player,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _playerTile(
    BuildContext context,
    PlayerRepository players,
    bool canManage,
    Player player,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: GestureDetector(
        onTap: player.photoBase64 != null
            ? () => showFullPhoto(context, player.photoBase64!)
            : null,
        child: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
          backgroundImage: player.photoBase64 != null
              ? MemoryImage(base64Decode(player.photoBase64!))
              : null,
          child: player.photoBase64 == null
              ? Text(
                  player.displayName.isNotEmpty
                      ? player.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : null,
        ),
      ),
      title: Text(player.displayName),
      subtitle: player.shortName != null && player.shortName!.isNotEmpty
          ? Text(player.fullName)
          : null,
      trailing: !canManage
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                  onPressed: () => _showEditDialog(context, players, player),
                ),
                if (player.active)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Marcar como inactivo',
                    onPressed: () => _confirmRemove(context, players, player),
                  )
                else ...[
                  IconButton(
                    icon: const Icon(Icons.restore),
                    tooltip: 'Reactivar',
                    onPressed: () => players.reactivatePlayer(player.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever_outlined),
                    tooltip: 'Eliminar para siempre',
                    onPressed: () =>
                        _confirmPermanentDelete(context, player),
                  ),
                ],
              ],
            ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    PlayerRepository players,
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
            Center(
              child: GestureDetector(
                onTap: player.photoBase64 != null
                    ? () => showFullPhoto(context, player.photoBase64!)
                    : null,
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  backgroundImage: player.photoBase64 != null
                      ? MemoryImage(base64Decode(player.photoBase64!))
                      : null,
                  child: player.photoBase64 == null
                      ? Text(
                          player.displayName.isNotEmpty
                              ? player.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                players.updatePlayer(
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

  void _confirmRemove(
    BuildContext context,
    PlayerRepository players,
    Player player,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Marcar como inactivo'),
        content: Text(
          '¿Quitar a ${player.displayName} de la lista de jugadores '
          'activos? Su historial de ganadas, perdidas y certificados no '
          'se borra, y lo puedes reactivar cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              players.removePlayer(player.id);
              Navigator.pop(dialogContext);
            },
            child: const Text('Marcar inactivo'),
          ),
        ],
      ),
    );
  }

  void _confirmPermanentDelete(BuildContext context, Player player) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar para siempre'),
        content: Text(
          '¿Borrar a ${player.displayName} para siempre? Si ya tiene '
          'ganadas, perdidas o partidas registradas, no se va a poder '
          'borrar (para no perder su historial de certificados y '
          'estadísticas). Esto no se puede deshacer.',
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
            onPressed: () async {
              final deletePlayerPermanently = context
                  .read<DeletePlayerPermanentlyUseCase>();
              Navigator.pop(dialogContext);
              try {
                await deletePlayerPermanently(player.id);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
                );
              }
            },
            child: const Text('Eliminar para siempre'),
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
