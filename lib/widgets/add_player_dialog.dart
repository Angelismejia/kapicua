import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

void showAddPlayerDialog(BuildContext context, FirestoreService firestore) {
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
          onPressed: () async {
            final fullName = fullNameController.text.trim();
            if (fullName.isEmpty) return;
            try {
              await firestore.addPlayer(
                fullName,
                shortName: shortNameController.text,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (e) {
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(
                dialogContext,
              ).showSnackBar(SnackBar(content: Text('No se pudo agregar: $e')));
            }
          },
          child: const Text('Agregar'),
        ),
      ],
    ),
  );
}
