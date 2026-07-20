import 'package:flutter/material.dart';

import '../../domain/entities/player.dart';
import '../../domain/usecases/merge_players_usecase.dart';

/// Diálogo (solo para admins de la familia, o para un invitado en su
/// propio espacio) para unificar dos fichas de jugador que en realidad
/// son la misma persona — ej. alguien perdió el acceso a su cuenta
/// vieja y se registró de nuevo, quedando dos jugadores duplicados con
/// su historial repartido entre ambos.
void showMergePlayersDialog(
  BuildContext context,
  MergePlayersUseCase mergePlayers,
  List<Player> players,
) {
  Player? keep;
  Player? remove;
  bool working = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Unificar jugadores duplicados'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para cuando la misma persona quedó con dos fichas '
                'separadas (ej. perdió su cuenta y se registró de nuevo). '
                'Todo el historial del segundo jugador (ganadas, '
                'perdidas, partidas, meses ganados) pasa al primero, y el '
                'segundo se borra.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Player>(
                initialValue: keep,
                decoration: const InputDecoration(
                  labelText: 'Jugador que se mantiene',
                ),
                items: players
                    .map(
                      (p) =>
                          DropdownMenuItem(value: p, child: Text(p.fullName)),
                    )
                    .toList(),
                onChanged: (p) => setState(() => keep = p),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Player>(
                initialValue: remove,
                decoration: const InputDecoration(
                  labelText: 'Jugador duplicado (se borra al final)',
                ),
                items: players
                    .map(
                      (p) =>
                          DropdownMenuItem(value: p, child: Text(p.fullName)),
                    )
                    .toList(),
                onChanged: (p) => setState(() => remove = p),
              ),
              if (keep != null && remove != null && keep!.id == remove!.id)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tienen que ser dos jugadores distintos.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: working ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed:
                (working ||
                    keep == null ||
                    remove == null ||
                    keep!.id == remove!.id)
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: dialogContext,
                      builder: (confirmContext) => AlertDialog(
                        title: const Text('¿Seguro?'),
                        content: Text(
                          'Se borrará "${remove!.displayName}" para '
                          'siempre, y su historial quedará bajo '
                          '"${keep!.displayName}". Esto no se puede '
                          'deshacer.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(confirmContext, false),
                            child: const Text('No'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            onPressed: () =>
                                Navigator.pop(confirmContext, true),
                            child: const Text('Sí, unificar'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;

                    setState(() => working = true);
                    try {
                      await mergePlayers(
                        keepPlayerId: keep!.id,
                        removePlayerId: remove!.id,
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '"${remove!.displayName}" se unificó con '
                            '"${keep!.displayName}" correctamente.',
                          ),
                        ),
                      );
                    } catch (e) {
                      setState(() => working = false);
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('No se pudo unificar: $e')),
                      );
                    }
                  },
            child: working
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Unificar'),
          ),
        ],
      ),
    ),
  );
}
