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
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => firestore
                                    .deletePlayerStatEntry(player.id, entry.id),
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
