import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Selector de mes/año compartido entre Estadísticas y Certificados, ya
/// que ambos son mensuales: al tocarlo se abre un calendario más grande
/// para saltar directo a cualquier mes en vez de ir uno por uno.
class MonthSelector extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  const MonthSelector({
    super.key,
    required this.month,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy', 'es').format(month);
    final capitalized = label[0].toUpperCase() + label.substring(1);
    return InkWell(
      onTap: () async {
        final picked = await showMonthYearPicker(context, month);
        if (picked != null) onChanged(picked);
      },
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
                fontWeight: FontWeight.w700,
                fontSize: 16,
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

Future<DateTime?> showMonthYearPicker(BuildContext context, DateTime initial) {
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => _MonthYearPickerDialog(initial: initial),
  );
}

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
        // Como máximo 280, pero se achica en pantallas angostas para
        // no desbordar el diálogo en un teléfono muy pequeño.
        width: (MediaQuery.of(context).size.width - 80).clamp(0, 280),
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
