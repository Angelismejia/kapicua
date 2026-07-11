import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../services/firestore_service.dart';
import 'family_gate_screen.dart';
import 'main_shell.dart';

/// Límite de tiempo para las consultas de Firestore que deciden qué
/// pantalla mostrar justo después de iniciar sesión. Sin esto, una
/// consulta que se traba por mala señal deja la pantalla de carga para
/// siempre, sin ningún error ni forma de reintentar. Se dejan 25 segundos
/// (no 15) porque reconectar la red de Firestore después de que el celular
/// estuvo bloqueado o cambiando de app puede tardar más de eso en datos
/// móviles, y 15 alcanzaba a mostrar "no hay conexión" con la conexión ya
/// recuperándose.
const _kGateTimeout = Duration(seconds: 25);

Widget _loadingScaffold() {
  return const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Un momento...'),
        ],
      ),
    ),
  );
}

Widget _errorScaffold(String message, VoidCallback onRetry) {
  return Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    ),
  );
}

/// Resuelve si el usuario entra como invitado o debe ver el PIN familiar.
/// Guarda el Future en el estado para no repetir la consulta cada vez que
/// la lista de jugadores se actualiza (lo que antes hacía parpadear la
/// pantalla de carga).
class GuestOrFamilyGate extends StatefulWidget {
  final String uid;

  const GuestOrFamilyGate({super.key, required this.uid});

  @override
  State<GuestOrFamilyGate> createState() => _GuestOrFamilyGateState();
}

class _GuestOrFamilyGateState extends State<GuestOrFamilyGate> {
  late Future<bool> _guestFuture;

  @override
  void initState() {
    super.initState();
    _startLookup();
  }

  void _startLookup() {
    debugPrint('[AuthGate] Consultando si es invitado (uid=${widget.uid})');
    _guestFuture = context
        .read<FirestoreService>()
        .hasGuestProfile(widget.uid)
        .timeout(_kGateTimeout);
  }

  @override
  void didUpdateWidget(covariant GuestOrFamilyGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _startLookup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    return FutureBuilder<bool>(
      future: _guestFuture,
      builder: (context, guestSnapshot) {
        if (guestSnapshot.connectionState == ConnectionState.waiting) {
          return _loadingScaffold();
        }
        if (guestSnapshot.hasError) {
          debugPrint(
            '[AuthGate] Error buscando invitado: ${guestSnapshot.error}',
          );
          return _errorScaffold(
            'No se pudo conectar. Revisa tu conexión e intenta de nuevo.',
            () => setState(_startLookup),
          );
        }
        if (guestSnapshot.data == true) {
          debugPrint('[AuthGate] Es invitado, mostrando Inicio');
          firestoreService.isGuest = true;
          firestoreService.guestUid = widget.uid;
          return const MainShell();
        }
        debugPrint('[AuthGate] No es invitado, mostrando PIN familiar');
        return const FamilyGateScreen();
      },
    );
  }
}

/// Busca el jugador vinculado a esta cuenta una sola vez por uid, en vez
/// de volver a consultar cada vez que se reconstruye el widget (algo que
/// puede pasar más de una vez seguida justo al iniciar sesión, si no se
/// memoriza el Future esto reinicia la consulta cada vez y la pantalla
/// se queda pegada esperando sin avanzar nunca).
class PlayerLookupGate extends StatefulWidget {
  final String uid;

  const PlayerLookupGate({super.key, required this.uid});

  @override
  State<PlayerLookupGate> createState() => _PlayerLookupGateState();
}

class _PlayerLookupGateState extends State<PlayerLookupGate> {
  late Future<Player?> _playerFuture;

  @override
  void initState() {
    super.initState();
    _startLookup();
  }

  void _startLookup() {
    debugPrint(
      '[AuthGate] Consultando perfil en Firestore (uid=${widget.uid})',
    );
    _playerFuture = context
        .read<FirestoreService>()
        .findPlayerByAuthUid(widget.uid)
        .timeout(_kGateTimeout);
  }

  @override
  void didUpdateWidget(covariant PlayerLookupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _startLookup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    return FutureBuilder<Player?>(
      future: _playerFuture,
      builder: (context, playerSnapshot) {
        if (playerSnapshot.connectionState == ConnectionState.waiting) {
          return _loadingScaffold();
        }
        if (playerSnapshot.hasError) {
          debugPrint(
            '[AuthGate] Error buscando perfil: ${playerSnapshot.error}',
          );
          return _errorScaffold(
            'No se pudo conectar. Revisa tu conexión e intenta de nuevo.',
            () => setState(_startLookup),
          );
        }
        if (playerSnapshot.data != null) {
          debugPrint('[AuthGate] Perfil recibido, mostrando Inicio');
          firestoreService.isGuest = false;
          return const MainShell();
        }
        debugPrint('[AuthGate] Sin perfil vinculado todavía');
        return GuestOrFamilyGate(uid: widget.uid);
      },
    );
  }
}
