import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/device_player_service.dart';

void showWhoAreYouDialog(
  BuildContext context,
  DevicePlayerService devicePlayer,
  List<Player> players,
) {
  showDialog(
    context: context,
    barrierDismissible: devicePlayer.playerId != null,
    builder: (dialogContext) => AlertDialog(
      title: const Text('¿Quién eres?'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            return ListTile(
              title: Text(player.displayName),
              onTap: () {
                devicePlayer.setPlayer(player.id);
                Navigator.pop(dialogContext);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Ahora no'),
        ),
      ],
    ),
  );
}
