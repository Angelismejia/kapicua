import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/monthly_winner.dart';
import '../widgets/manual_certificate_dialog.dart';
import '../widgets/month_selector.dart';
import '../widgets/monthly_winner_card.dart';

class CertificadosTab extends StatefulWidget {
  const CertificadosTab({super.key});

  @override
  State<CertificadosTab> createState() => _CertificadosTabState();
}

class _CertificadosTabState extends State<CertificadosTab> {
  late DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final auth = context.watch<AuthService>();
    final isAdmin = auth.isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Certificados')),
      body: StreamBuilder<List<Player>>(
        stream: firestore.watchAllPlayers(),
        builder: (context, playersSnap) {
          final players = playersSnap.data ?? [];

          Player? me;
          for (final p in players) {
            if (p.authUid == auth.currentUser?.uid) me = p;
          }

          return StreamBuilder<List<PlayerStatEntry>>(
            stream: firestore.watchAllStatEntries(),
            builder: (context, entriesSnap) {
              final entries = entriesSnap.data ?? [];

              // Si el mes no tiene ni una sola ganada o perdida registrada
              // (ej. un mes anterior a que se empezara a usar la app), no
              // se inventa un líder: no hay nada que mostrar. El "siempre
              // hay alguien arriba" solo aplica a un mes que sí se está
              // jugando (aunque nadie tenga una ganada todavía).
              final hasActivityThisMonth = entries.any(
                (e) =>
                    e.createdAt.year == _selectedMonth.year &&
                    e.createdAt.month == _selectedMonth.month,
              );
              final leader = hasActivityThisMonth
                  ? computeMonthlyLeaderOrFallback(
                      entries,
                      players,
                      _selectedMonth,
                    )
                  : null;
              final isMeTheLeader =
                  leader != null && me != null && leader.player.id == me.id;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  MonthSelector(
                    month: _selectedMonth,
                    onChanged: (m) => setState(() => _selectedMonth = m),
                  ),
                  const SizedBox(height: 16),
                  ..._buildChampionSection(
                    isAdmin,
                    leader,
                    isMeTheLeader,
                    players.isEmpty,
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 24),
                    Text(
                      '¿Necesitas otro certificado?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Genera uno manualmente con cualquier nombre, mes o puntaje.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.edit_document),
                      label: const Text('Certificado manual'),
                      onPressed: () =>
                          showManualCertificateDialog(context, players),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildChampionSection(
    bool isAdmin,
    MonthlyWinnerResult? leader,
    bool isMeTheLeader,
    bool noPlayers,
  ) {
    if (leader == null) {
      if (noPlayers) {
        return const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Agrega jugadores a la liga para ver certificados.'),
            ),
          ),
        ];
      }
      // Mes sin ninguna actividad registrada: no se inventa nada.
      return const [];
    }

    final label = DateFormat('MMMM yyyy', 'es').format(_selectedMonth);

    if (isAdmin) {
      return [
        if (!leader.isMonthOver) ...[
          Text(
            'Todavía no hay ganador oficial este mes.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
        MonthlyWinnerCard(result: leader),
      ];
    }

    // No admin: mensaje general de quién va/fue ganando, y uno
    // personalizado según si el que ve la pantalla es quien lidera.
    final statusText = leader.isMonthOver
        ? 'El ganador de $label fue ${leader.player.displayName}.'
        : '${leader.player.displayName} va ganando este mes, pero el '
              'resultado todavía no está definido.';
    final personalText = isMeTheLeader
        ? '¡Estás ganando este mes! Sigue así, vas muy bien.'
        : 'Sigue jugando, el próximo mes puede ser tuyo.';

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(statusText),
              const SizedBox(height: 8),
              Text(
                personalText,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      if (isMeTheLeader) ...[
        const SizedBox(height: 16),
        MonthlyWinnerCard(result: leader),
      ],
    ];
  }
}
