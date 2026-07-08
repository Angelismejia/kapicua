import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/player.dart';
import '../models/player_stat_entry.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/monthly_winner.dart';
import '../widgets/manual_certificate_dialog.dart';
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

  Future<void> _openMonthPicker() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) =>
          _MonthYearPickerDialog(initial: _selectedMonth),
    );
    if (picked != null) setState(() => _selectedMonth = picked);
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
                  _MonthSelector(
                    month: _selectedMonth,
                    onTap: _openMonthPicker,
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
      if (isAdmin || isMeTheWinner) {
        return [MonthlyWinnerCard(result: monthlyWinner)];
      }
      // No admin y no es quien ganó: informativo, sin botón de certificado.
      final label = DateFormat('MMMM yyyy', 'es').format(_selectedMonth);
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'El campeón de $label fue ${monthlyWinner.player.displayName}.',
            ),
          ),
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
              ? const Text('Todavía no hay partidas ganadas este mes.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aún no tienes certificado este mes 🎯',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '¡Dale con todo! Cuando seas el jugador con más '
                      'victorias del mes, tu certificado va a '
                      'aparecer justo aquí.',
                    ),
                  ],
                ),
        ),
      ),
    ];
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onTap;

  const _MonthSelector({required this.month, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy', 'es').format(month);
    final capitalized = label[0].toUpperCase() + label.substring(1);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month_rounded, size: 18),
            const SizedBox(width: 8),
            Text(
              capitalized,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Selector de mes y año más grande, para saltar directo a cualquier mes
/// en vez de tener que ir mes a mes con flechitas.
class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime initial;

  const _MonthYearPickerDialog({required this.initial});

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year = widget.initial.year;

  static const _monthLabels = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentYear = _year == now.year;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setState(() => _year--),
          ),
          Text('$_year'),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: isCurrentYear ? null : () => setState(() => _year++),
          ),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: [
            for (var m = 1; m <= 12; m++)
              _buildMonthButton(m, isCurrentYear && m > now.month),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildMonthButton(int month, bool disabled) {
    final selected =
        _year == widget.initial.year && month == widget.initial.month;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        padding: EdgeInsets.zero,
      ),
      onPressed: disabled
          ? null
          : () => Navigator.pop(context, DateTime(_year, month)),
      child: Text(_monthLabels[month - 1]),
    );
  }
}
