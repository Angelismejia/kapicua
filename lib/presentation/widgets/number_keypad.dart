import 'package:flutter/material.dart';

/// Teclado numérico propio (1-9, 0 y borrar), reutilizado en cualquier
/// diálogo donde sea más rápido tocar números grandes que abrir el
/// teclado del sistema (ej. sumar una ronda, agregar ganadas/perdidas).
class NumberKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const NumberKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Expanded(
        child: AspectRatio(
          aspectRatio: 1.5,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Material(
              color: Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Center(
                  child:
                      child ??
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) key(d, onTap: () => onDigit(d))]),
        Row(
          children: [
            key('', onTap: null),
            key('0', onTap: () => onDigit('0')),
            key(
              '',
              onTap: onBackspace,
              child: const Icon(Icons.backspace_outlined, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}
