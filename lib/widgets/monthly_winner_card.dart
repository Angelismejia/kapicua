import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../screens/certificate_screen.dart';
import '../utils/monthly_winner.dart';
import 'photo_viewer.dart';

class MonthlyWinnerCard extends StatelessWidget {
  final MonthlyWinnerResult result;
  final bool canGenerate;
  final bool isMe;

  const MonthlyWinnerCard({
    super.key,
    required this.result,
    this.canGenerate = true,
    this.isMe = false,
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
                  ? (isMe
                        ? '¡Felicidades, ganaste $monthLabelLower!'
                        : 'El ganador de $monthLabelLower fue')
                  : (isMe
                        ? '¡Felicidades, vas ganando este mes!'
                        : 'Va ganando este mes'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: result.player.photoBase64 != null
                      ? () => showFullPhoto(context, result.player.photoBase64!)
                      : null,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.15),
                    backgroundImage: result.player.photoBase64 != null
                        ? MemoryImage(base64Decode(result.player.photoBase64!))
                        : null,
                    child: result.player.photoBase64 == null
                        ? Text(
                            result.player.displayName.isNotEmpty
                                ? result.player.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    isMonthOver
                        ? result.player.displayName
                        : '🔥 ${result.player.displayName}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '¡Eres tú!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ],
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
