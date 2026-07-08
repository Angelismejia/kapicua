import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../screens/certificate_screen.dart';
import '../utils/monthly_winner.dart';

class MonthlyWinnerCard extends StatelessWidget {
  final MonthlyWinnerResult result;

  /// Versión reducida: usada en Estadísticas, donde ya hay un selector de
  /// mes arriba y no conviene que esta tarjeta ocupe tanto espacio.
  final bool compact;

  const MonthlyWinnerCard({
    super.key,
    required this.result,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'es').format(result.month);
    final isMonthOver = result.isMonthOver;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMonthOver ? 'Ganador del mes' : 'Por ahora, va ganando...',
              style: compact
                  ? Theme.of(context).textTheme.labelMedium
                  : Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: compact ? 2 : 8),
            Text(
              isMonthOver
                  ? result.player.displayName
                  : '🔥 ${result.player.displayName}',
              style: compact
                  ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )
                  : Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '${result.wins} partidas ganadas',
              style: compact ? Theme.of(context).textTheme.bodySmall : null,
            ),
            SizedBox(height: compact ? 8 : 12),
            SizedBox(
              height: compact ? 36 : null,
              child: FilledButton.icon(
                style: compact
                    ? FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontSize: 12.5),
                      )
                    : null,
                icon: Icon(Icons.workspace_premium, size: compact ? 16 : 24),
                label: const Text('Generar certificado'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CertificateScreen(
                      winnerName: result.player.fullName,
                      monthLabel: monthLabel,
                      totalScore: result.certificateScore,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
