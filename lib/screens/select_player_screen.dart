import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../services/firestore_service.dart';
import 'complete_profile_screen.dart';

/// Paso dedicado, aparte, para elegir tu nombre de la lista antes de
/// completar el registro — separado del resto del formulario para que
/// se note bien y nadie termine escogiendo "soy nuevo" por error cuando
/// ya estaba en la lista (eso deja dos fichas duplicadas del mismo
/// jugador).
class SelectPlayerScreen extends StatefulWidget {
  const SelectPlayerScreen({super.key});

  @override
  State<SelectPlayerScreen> createState() => _SelectPlayerScreenState();
}

class _SelectPlayerScreenState extends State<SelectPlayerScreen> {
  // Se crea una sola vez para que la lista cargue rápido y no se quede
  // pegada ni parpadee vacía si esta pantalla se reconstruye.
  late final Stream<List<Player>> _playersStream;

  @override
  void initState() {
    super.initState();
    _playersStream = context.read<FirestoreService>().watchAllPlayers();
  }

  void _choose(String? playerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompleteProfileScreen(selectedPlayerId: playerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿Quién eres?')),
      body: StreamBuilder<List<Player>>(
        stream: _playersStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final unlinked = snapshot.data!
              .where((p) => p.authUid == null)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Elige tu nombre de la lista',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Si ya estás en la lista de la liga, tócalo aquí en vez de '
                'crear uno nuevo — así no queda duplicado.',
              ),
              const SizedBox(height: 16),
              if (unlinked.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Todavía no hay nadie sin cuenta en la lista.'),
                )
              else
                ...unlinked.map(
                  (p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(p.fullName),
                      subtitle: p.shortName != null && p.shortName!.isNotEmpty
                          ? Text(p.shortName!)
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _choose(p.id),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Soy nuevo, no estoy en la lista'),
                onPressed: () => _choose(null),
              ),
            ],
          );
        },
      ),
    );
  }
}
