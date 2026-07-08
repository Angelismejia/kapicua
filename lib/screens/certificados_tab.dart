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

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

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
              final monthlyWinner = computeMonthlyWinner(
                entries,
                players,
                _selectedMonth,
              );
              final isMeTheWinner =
                  monthlyWinner != null &&
                  me != null &&
                  monthlyWinner.player.id == me.id;

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
                    monthlyWinner,
                    isMeTheWinner,
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
    MonthlyWinnerResult? monthlyWinner,
    bool isMeTheWinner,
  ) {
    if (monthlyWinner != null) {
      // Si el mes sigue en curso, se aclara que todavía no hay un ganador
      // oficial (el certificado no existe hasta que termine el mes),
      // pero igual se muestra quién va ganando por ahora.
      final notice = monthlyWinner.isMonthOver
          ? const <Widget>[]
          : <Widget>[
              Text(
                'Todavía no hay un ganador oficial este mes.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ];

      if (isAdmin || isMeTheWinner) {
        return [...notice, MonthlyWinnerCard(result: monthlyWinner)];
      }
      // No admin y no es quien ganó: informativo, sin botón de certificado.
      final label = DateFormat('MMMM yyyy', 'es').format(_selectedMonth);
      final text = monthlyWinner.isMonthOver
          ? 'El campeón de $label fue ${monthlyWinner.player.displayName}.'
          : 'Por ahora, en $label va ganando '
                '${monthlyWinner.player.displayName}.';
      return [
        ...notice,
        Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
        ),
      ];
    }

    // Sin campeón registrado ese mes.
    if (!_isCurrentMonth) return const [];

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isAdmin
              ? const Text('Todavía no hay ganador en el mes.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aquí verás tus certificados 🎯',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sigue jugando para ser el jugador con más victorias '
                      'del mes — cuando lo logres, tu certificado va a '
                      'aparecer justo aquí.',
                    ),
                  ],
                ),
        ),
      ),
    ];
  }
}
