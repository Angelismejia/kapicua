import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../services/firestore_service.dart';
import 'number_keypad.dart';

/// Mensaje de confirmación arriba de la pantalla (no abajo como el
/// SnackBar normal), para que se note justo después de borrar/editar.
void _showTopMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearMaterialBanners();
  final banner = MaterialBanner(
    content: Text(message),
    actions: [
      TextButton(
        onPressed: messenger.clearMaterialBanners,
        child: const Text('OK'),
      ),
    ],
  );
  messenger.showMaterialBanner(banner);
  Future.delayed(const Duration(seconds: 3), messenger.clearMaterialBanners);
}

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

const _kStatsGreen = Color(0xFF2E6B3F);

void _showAddStatDialog(
  BuildContext context,
  FirestoreService firestore,
  String playerId,
  DateTime forMonth,
) {
  var isWin = true;
  var digits = '';

  Widget typeButton(
    bool value,
    String label,
    bool isWinState,
    void Function(void Function()) setState,
  ) {
    final selected = isWinState == value;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: selected
                ? _kStatsGreen.withValues(alpha: 0.12)
                : null,
            side: BorderSide(
              color: selected ? _kStatsGreen : Colors.grey.shade400,
              width: selected ? 2 : 1,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => setState(() => isWin = value),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? _kStatsGreen : null,
            ),
          ),
        ),
      ),
    );
  }

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final display = digits.isEmpty ? '1' : digits;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '¿Qué anotamos?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMMM yyyy', 'es').format(forMonth),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      typeButton(true, 'Ganada', isWin, setState),
                      typeButton(false, 'Perdida', isWin, setState),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    display,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 48,
                    ),
                  ),
                  Text(
                    '¿Cuántas fueron?',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  NumberKeypad(
                    onDigit: (d) => setState(() {
                      if (digits.length < 3) digits += d;
                    }),
                    onBackspace: () => setState(() {
                      if (digits.isNotEmpty) {
                        digits = digits.substring(0, digits.length - 1);
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _kStatsGreen,
                          ),
                          onPressed: () {
                            final count = int.tryParse(display) ?? 1;
                            Navigator.pop(dialogContext);
                            _addEntries(
                              context,
                              firestore,
                              playerId,
                              isWin,
                              count < 1 ? 1 : count,
                              forMonth,
                            );
                          },
                          child: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
      _showTopMessage(context, 'Estadística eliminada correctamente.');
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
      _showTopMessage(context, 'Estadística editada correctamente.');
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
          final deletedCount = selectedIds.length;
          try {
            await firestore.deletePlayerStatEntries(
              player.id,
              selectedIds.toList(),
            );
            setState(() {
              selectedIds.clear();
              selecting = false;
            });
            if (!context.mounted) return;
            _showTopMessage(
              context,
              '$deletedCount estadística${deletedCount == 1 ? '' : 's'} '
              'eliminada${deletedCount == 1 ? '' : 's'} correctamente.',
            );
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
              CircleAvatar(
                radius: 28,
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
                          fontSize: 22,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(player.displayName),
                    Text(
                      DateFormat('MMMM yyyy', 'es').format(forMonth),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
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
                      final entries = (snapshot.data ?? [])
                          .where(
                            (e) =>
                                e.createdAt.year == forMonth.year &&
                                e.createdAt.month == forMonth.month,
                          )
                          .toList();
                      if (entries.isEmpty) {
                        return const Center(
                          child: Text(
                            'No hay ganadas ni perdidas registradas este mes.',
                          ),
                        );
                      }
                      final allSelected = entries.every(
                        (e) => selectedIds.contains(e.id),
                      );
                      return Column(
                        children: [
                          if (selecting)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text('Seleccionar todas'),
                              value: allSelected,
                              onChanged: (_) => setState(() {
                                if (allSelected) {
                                  selectedIds.clear();
                                } else {
                                  selectedIds
                                    ..clear()
                                    ..addAll(entries.map((e) => e.id));
                                }
                              }),
                            ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                final isSelected = selectedIds.contains(
                                  entry.id,
                                );
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
                                  title: Text(
                                    entry.isWin ? 'Ganada' : 'Perdida',
                                  ),
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
                            ),
                          ),
                        ],
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
