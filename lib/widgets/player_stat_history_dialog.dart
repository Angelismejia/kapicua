import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../services/firestore_service.dart';

/// Si se está viendo un mes pasado en el calendario, lo que se agregue
/// debe quedar fechado ese mes (no el día de hoy), conservando el mismo
/// día/hora para que se sienta natural.
DateTime _dateWithinMonth(DateTime month) {
  final now = DateTime.now();
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  final day = now.day > lastDay ? lastDay : now.day;
  return DateTime(month.year, month.month, day, now.hour, now.minute);
}

Future<void> _addEntries(
  BuildContext context,
  FirestoreService firestore,
  String playerId,
  bool isWin,
  int count,
  DateTime forMonth,
) async {
  try {
    await firestore.addPlayerStatEntries(
      playerId,
      isWin,
      count,
      date: _dateWithinMonth(forMonth),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
  }
}

void _showAddStatDialog(
  BuildContext context,
  FirestoreService firestore,
  String playerId,
  DateTime forMonth,
) {
  var isWin = true;
  final quantityController = TextEditingController(text: '1');

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Agregar ganadas o perdidas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se guardará en ${DateFormat('MMMM yyyy', 'es').format(forMonth)}. '
              'Elige si son ganadas o perdidas, y cuántas quieres '
              'agregar de una vez.',
            ),
            const SizedBox(height: 8),
            RadioListTile<bool>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Ganada'),
              value: true,
              groupValue: isWin,
              onChanged: (v) => setState(() => isWin = v!),
            ),
            RadioListTile<bool>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Perdida'),
              value: false,
              groupValue: isWin,
              onChanged: (v) => setState(() => isWin = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cuántas quieres agregar',
                helperText:
                    'Ej. escribe 13 si quieres agregar 13 ganadas '
                    'ya jugadas antes, de una sola vez.',
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
              final n = int.tryParse(quantityController.text.trim());
              final count = (n == null || n < 1) ? 1 : n;
              Navigator.pop(dialogContext);
              _addEntries(context, firestore, playerId, isWin, count, forMonth);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
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
    try {
      await firestore.deletePlayerStatEntry(playerId, entry.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estadística eliminada correctamente.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estadística editada correctamente.')),
      );
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
  DateTime forMonth,
) {
  var selecting = false;
  final selectedIds = <String>{};

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        Future<void> deleteSelected() async {
          final confirmed = await showDialog<bool>(
            context: dialogContext,
            builder: (confirmContext) => AlertDialog(
              title: const Text('Eliminar seleccionadas'),
              content: Text(
                '¿Borrar ${selectedIds.length} estadística'
                '${selectedIds.length == 1 ? '' : 's'} seleccionada'
                '${selectedIds.length == 1 ? '' : 's'}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(confirmContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => Navigator.pop(confirmContext, true),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          try {
            await firestore.deletePlayerStatEntries(
              player.id,
              selectedIds.toList(),
            );
            setState(() {
              selectedIds.clear();
              selecting = false;
            });
          } catch (e) {
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(
              dialogContext,
            ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
          }
        }

        return AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text(player.displayName)),
              if (isAdmin)
                IconButton(
                  icon: Icon(selecting ? Icons.close : Icons.checklist_rounded),
                  tooltip: selecting
                      ? 'Cancelar selección'
                      : 'Seleccionar varias',
                  onPressed: () => setState(() {
                    selecting = !selecting;
                    selectedIds.clear();
                  }),
                ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: Column(
              children: [
                if (isAdmin && !selecting) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar ganadas o perdidas'),
                      onPressed: () => _showAddStatDialog(
                        dialogContext,
                        firestore,
                        player.id,
                        forMonth,
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                ],
                if (isAdmin && selecting) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: Text('Eliminar (${selectedIds.length})'),
                      onPressed: selectedIds.isEmpty ? null : deleteSelected,
                    ),
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
                          final isSelected = selectedIds.contains(entry.id);
                          return ListTile(
                            dense: true,
                            leading: selecting
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => setState(() {
                                      if (isSelected) {
                                        selectedIds.remove(entry.id);
                                      } else {
                                        selectedIds.add(entry.id);
                                      }
                                    }),
                                  )
                                : Icon(
                                    entry.isWin
                                        ? Icons.emoji_events
                                        : Icons.close_rounded,
                                    color: entry.isWin
                                        ? Colors.green
                                        : Colors.redAccent,
                                  ),
                            title: Text(entry.isWin ? 'Ganada' : 'Perdida'),
                            subtitle: Text(
                              DateFormat(
                                'd MMM yyyy, h:mm a',
                                'es',
                              ).format(entry.createdAt),
                            ),
                            trailing: isAdmin && !selecting
                                ? const Icon(Icons.chevron_right)
                                : null,
                            onTap: !isAdmin
                                ? null
                                : selecting
                                ? () => setState(() {
                                    if (isSelected) {
                                      selectedIds.remove(entry.id);
                                    } else {
                                      selectedIds.add(entry.id);
                                    }
                                  })
                                : () => _editEntry(
                                    context,
                                    firestore,
                                    player.id,
                                    entry,
                                  ),
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
        );
      },
    ),
  );
}
