import 'package:flutter/material.dart';

import '../../domain/repositories/player_repository.dart';

void showAddPlayerDialog(BuildContext context, PlayerRepository players) {
  final fullNameController = TextEditingController();
  final shortNameController = TextEditingController();
  var saving = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
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
            onPressed: saving ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            // Sin esto, dos toques rápidos antes de que se cierre el
            // diálogo alcanzan a crear el jugador dos veces.
            onPressed: saving
                ? null
                : () async {
                    final fullName = fullNameController.text.trim();
                    if (fullName.isEmpty) return;
                    setState(() => saving = true);
                    try {
                      await players.addPlayer(
                        fullName,
                        shortName: shortNameController.text,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      setState(() => saving = false);
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('No se pudo agregar: $e')),
                      );
                    }
                  },
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Agregar'),
          ),
        ],
      ),
    ),
  );
}
