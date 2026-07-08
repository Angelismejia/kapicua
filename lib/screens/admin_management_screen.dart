import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Pantalla para dar o quitar permisos de administrador a otros jugadores
/// de la liga, sin tener que tocar código. Solo la ven los admins.
class AdminManagementScreen extends StatelessWidget {
  const AdminManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final myUid = context.read<AuthService>().currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Administradores')),
      body: StreamBuilder<List<Player>>(
        stream: firestore.watchAllPlayers(),
        builder: (context, playersSnap) {
          final players = playersSnap.data ?? [];
          return StreamBuilder<Set<String>>(
            stream: firestore.watchAdminUids(),
            builder: (context, adminsSnap) {
              final adminUids = adminsSnap.data ?? {};

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Elige quién más puede editar estadísticas, generar '
                    'certificados manuales y administrar la liga. Solo '
                    'puedes dar permisos a jugadores que ya crearon su '
                    'cuenta.',
                  ),
                  const SizedBox(height: 16),
                  for (final player in players)
                    _AdminTile(
                      player: player,
                      isAdmin:
                          player.authUid != null &&
                          adminUids.contains(player.authUid),
                      isMe: player.authUid == myUid,
                      onChanged: player.authUid == null
                          ? null
                          : (value) async {
                              try {
                                if (value) {
                                  await firestore.grantAdmin(player.authUid!);
                                } else {
                                  await firestore.revokeAdmin(player.authUid!);
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('No se pudo actualizar: $e'),
                                  ),
                                );
                              }
                            },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final Player player;
  final bool isAdmin;
  final bool isMe;
  final ValueChanged<bool>? onChanged;

  const _AdminTile({
    required this.player,
    required this.isAdmin,
    required this.isMe,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        title: Text(player.displayName + (isMe ? ' (tú)' : '')),
        subtitle: Text(
          player.authUid == null
              ? 'Aún no tiene cuenta creada'
              : (isAdmin ? 'Es administrador' : 'Cuenta de jugador'),
        ),
        value: isAdmin,
        onChanged: isMe ? null : onChanged,
      ),
    );
  }
}
