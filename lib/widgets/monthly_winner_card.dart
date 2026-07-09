import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../screens/certificate_screen.dart';
import '../utils/monthly_winner.dart';

class MonthlyWinnerCard extends StatelessWidget {
  final MonthlyWinnerResult result;
  final bool canGenerate;

  const MonthlyWinnerCard({
    super.key,
    required this.result,
    this.canGenerate = true,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'es').format(result.month);
    final monthLabelLower =
        monthLabel[0].toLowerCase() + monthLabel.substring(1);
    final isMonthOver = result.isMonthOver;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMonthOver
                  ? 'El ganador de $monthLabelLower fue'
                  : 'Va ganando este mes',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              isMonthOver
                  ? result.player.displayName
                  : '🔥 ${result.player.displayName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${result.wins} ganadas · ${result.losses} perdidas · '
              '${result.totalGames} en total · '
              '${result.winPercentage.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (canGenerate) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.workspace_premium),
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
            ],
          ],
        ),
      ),
    );
  }
}
