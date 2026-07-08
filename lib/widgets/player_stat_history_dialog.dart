import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../services/firestore_service.dart';

Future<void> _addEntry(
  BuildContext context,
  FirestoreService firestore,
  String playerId,
  bool isWin,
) async {
  try {
    await firestore.addPlayerStatEntry(playerId, isWin);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
  }
}

Future<void> _editEntry(
  BuildContext context,
  FirestoreService firestore,
  String playerId,
  PlayerStatEntry entry,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              entry.isWin ? Icons.emoji_events : Icons.close_rounded,
              color: entry.isWin ? Colors.green : Colors.redAccent,
            ),
            title: Text(
              entry.isWin ? 'Editar esta ganada' : 'Editar esta perdida',
            ),
            subtitle: Text(
              DateFormat('d MMM yyyy, h:mm a', 'es').format(entry.createdAt),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined),
            title: const Text('Cambiar fecha'),
            onTap: () => Navigator.pop(sheetContext, 'date'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Eliminar'),
            onTap: () => Navigator.pop(sheetContext, 'delete'),
          ),
        ],
      ),
    ),
  );

  if (action == 'delete') {
    await firestore.deletePlayerStatEntry(playerId, entry.id);
    return;
  }
  if (action == 'date') {
    if (!context.mounted) return;
    final newDate = await showDatePicker(
      context: context,
      initialDate: entry.createdAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (newDate == null) return;
    final updated = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      entry.createdAt.hour,
      entry.createdAt.minute,
    );
    try {
      await firestore.updatePlayerStatEntryDate(playerId, entry.id, updated);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    }
  }
}

void showPlayerStatHistoryDialog(
  BuildContext context,
  FirestoreService firestore,
  Player player,
  bool isAdmin,
) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(player.displayName),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            if (isAdmin) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Ganada'),
                      onPressed: () =>
                          _addEntry(dialogContext, firestore, player.id, true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Perdida'),
                      onPressed: () =>
                          _addEntry(dialogContext, firestore, player.id, false),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
            ],
            Expanded(
              child: StreamBuilder<List<PlayerStatEntry>>(
                stream: firestore.watchPlayerStatEntries(player.id),
                builder: (context, snapshot) {
                  final entries = snapshot.data ?? [];
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text('Todavía no hay partidas registradas.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          entry.isWin
                              ? Icons.emoji_events
                              : Icons.close_rounded,
                          color: entry.isWin ? Colors.green : Colors.redAccent,
                        ),
                        title: Text(entry.isWin ? 'Ganada' : 'Perdida'),
                        subtitle: Text(
                          DateFormat(
                            'd MMM yyyy, h:mm a',
                            'es',
                          ).format(entry.createdAt),
                        ),
                        trailing: isAdmin
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap: isAdmin
                            ? () => _editEntry(
                                context,
                                firestore,
                                player.id,
                                entry,
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
