import 'package:flutter/material.dart';

/// Widgets del marcador de dos columnas (Casa | Visita), compartidos entre
/// la partida en curso y el detalle de una partida ya terminada en el
/// historial, para que ambos se vean iguales.
class ScoreSheetHeader extends StatelessWidget {
  final String label;
  final String playerNames;

  const ScoreSheetHeader({
    super.key,
    required this.label,
    required this.playerNames,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            playerNames,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class ScoreSheetCell extends StatelessWidget {
  final int value;

  const ScoreSheetCell({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text('$value', style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

class ScoreSheetTotal extends StatelessWidget {
  final int value;

  const ScoreSheetTotal({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
