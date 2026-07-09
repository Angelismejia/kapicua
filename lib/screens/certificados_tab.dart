import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'certificate_screen.dart';

/// Todos los meses (ya terminados) que este jugador ganó, sin importar
/// cuál mes esté seleccionado en el calendario de arriba — para que su
/// historial de certificados se vea completo siempre, no solo el mes
/// que esté mirando en ese momento. Incluye tanto los meses con ganadas
/// reales como los ganadores viejos puestos a mano por un admin.
List<MonthlyWinnerResult> _myWonMonths(
  List<PlayerStatEntry> entries,
  List<Player> players,
  Player me,
  Map<String, Map<String, dynamic>> overrides,
) {
  final months = <DateTime>{};
  for (final e in entries) {
    months.add(DateTime(e.createdAt.year, e.createdAt.month));
  }
  final won = <MonthlyWinnerResult>[];
  final wonMonthKeys = <String>{};
  for (final month in months) {
    final leader = computeMonthlyLeaderOrFallback(entries, players, month);
    if (leader != null && leader.isMonthOver && leader.player.id == me.id) {
      won.add(leader);
      wonMonthKeys.add(
        '${month.year}-${month.month.toString().padLeft(2, '0')}',
      );
    }
  }

  // Meses viejos sin ninguna ganada/perdida registrada, pero con un
  // ganador declarado a mano por un admin.
  overrides.forEach((monthKey, data) {
    if (wonMonthKeys.contains(monthKey)) return;
    if (data['playerId'] != me.id) return;
    final parts = monthKey.split('-');
    if (parts.length != 2) return;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return;
    won.add(
      MonthlyWinnerResult(
        player: me,
        month: DateTime(year, month),
        wins: (data['wins'] as num?)?.toInt() ?? 0,
        losses: (data['losses'] as num?)?.toInt() ?? 0,
      ),
    );
  });

  won.sort((a, b) => b.month.compareTo(a.month));
  return won;
}

void _showSetOverrideDialog(
  BuildContext context,
  FirestoreService firestore,
  List<Player> players,
  DateTime month, {
  Player? currentPlayer,
  int currentWins = 1,
  int currentLosses = 0,
}) {
  Player? selected =
      currentPlayer ?? (players.isNotEmpty ? players.first : null);
  final winsController = TextEditingController(text: '$currentWins');
  final lossesController = TextEditingController(text: '$currentLosses');

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(
          currentPlayer == null
              ? 'Establecer ganador de este mes'
              : 'Corregir ganador de este mes',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para meses sin ninguna ganada o perdida registrada (ej. '
              'antes de usar la app). Elige quién ganó y sus estadísticas.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Player>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Jugador'),
              items: players
                  .map(
                    (p) => DropdownMenuItem(value: p, child: Text(p.fullName)),
                  )
                  .toList(),
              onChanged: (p) => setState(() => selected = p),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: winsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Ganadas'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lossesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Perdidas'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: selected == null
                ? null
                : () async {
                    final wins = int.tryParse(winsController.text.trim()) ?? 0;
                    final losses =
                        int.tryParse(lossesController.text.trim()) ?? 0;
                    Navigator.pop(dialogContext);
                    try {
                      await firestore.setMonthlyOverride(
                        month,
                        selected!.id,
                        wins,
                        losses,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No se pudo guardar: $e')),
                      );
                    }
                  },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

class CertificadosTab extends StatefulWidget {
  const CertificadosTab({super.key});

  @override
  State<CertificadosTab> createState() => _CertificadosTabState();
}

/// Frases cuando vas de primero este mes. Se elige una al azar cada vez
/// que se entra a la pantalla, para que no se sienta repetitivo.
const _kLeaderMessages = [
  '¡Vas de primero este mes! Ahora toca defender el puesto.',
  'El liderato es tuyo — que no te lo quiten tan fácil.',
  'Sigues arriba. Todos quieren tu puesto, no lo sueltes.',
  'De primero y con todo. Mantén el ritmo hasta que se acabe el mes.',
];

/// Frases cuando estás cerca del que va ganando (a pocas ganadas).
const _kCloseMessages = [
  'Estás cerca del primer lugar — una buena racha y te pones arriba.',
  'No estás lejos de la punta. Unas ganadas más y volteas esto.',
  'El primer puesto está al alcance. Ve por él.',
  'Todavía puedes voltear esto antes de que se acabe el mes.',
];

/// Frases generales para cuando vas más atrás o recién empiezas el mes.
const _kBehindMessages = [
  'Todavía queda mes por delante — dale que esto se puede voltear.',
  'No importa cómo empiezas el mes, importa cómo lo terminas.',
  'Cada partida es una oportunidad de subir en la tabla.',
  'El dominó da muchas vueltas — hoy vas abajo, el mes que viene puedes ser el campeón.',
  'Sigue jugando, todavía hay tiempo de remontar.',
];

class _CertificadosTabState extends State<CertificadosTab> {
  late DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  // Se elige una sola vez por visita a la pantalla (no en cada rebuild,
  // que pasaría seguido por los streams de Firestore), para que el
  // mensaje se sienta estable mientras se está viendo, pero cambie la
  // próxima vez que se entre a Certificados.
  final int _messageSeed = DateTime.now().microsecondsSinceEpoch;

  String _pickMessage(List<String> pool) => pool[_messageSeed % pool.length];

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
              // se inventa un líder: no hay nada que mostrar, a menos que
              // un admin haya declarado un ganador a mano para ese mes.
              // El "siempre hay alguien arriba" solo aplica a un mes que
              // sí se está jugando (aunque nadie tenga una ganada aún).
              final hasActivityThisMonth = entries.any(
                (e) =>
                    e.createdAt.year == _selectedMonth.year &&
                    e.createdAt.month == _selectedMonth.month,
              );

              return StreamBuilder<Map<String, dynamic>?>(
                stream: firestore.watchMonthlyOverride(_selectedMonth),
                builder: (context, overrideSnap) {
                  final override = overrideSnap.data;

                  MonthlyWinnerResult? leader;
                  if (hasActivityThisMonth) {
                    leader = computeMonthlyLeaderOrFallback(
                      entries,
                      players,
                      _selectedMonth,
                    );
                  } else if (override != null) {
                    final overridePlayer = players
                        .where((p) => p.id == override['playerId'])
                        .cast<Player?>()
                        .firstWhere((_) => true, orElse: () => null);
                    if (overridePlayer != null) {
                      leader = MonthlyWinnerResult(
                        player: overridePlayer,
                        month: _selectedMonth,
                        wins: (override['wins'] as num?)?.toInt() ?? 0,
                        losses: (override['losses'] as num?)?.toInt() ?? 0,
                      );
                    }
                  }
                  final isMeTheLeader =
                      leader != null && me != null && leader.player.id == me.id;

                  // Cuántas ganadas me faltan para alcanzar al líder este
                  // mes (solo tiene sentido si todavía no soy yo quien va
                  // arriba), para elegir un mensaje motivador acorde.
                  int? gapToLeader;
                  if (leader != null && me != null && !isMeTheLeader) {
                    final myWins = entries
                        .where(
                          (e) =>
                              e.playerId == me!.id &&
                              e.isWin &&
                              e.createdAt.year == _selectedMonth.year &&
                              e.createdAt.month == _selectedMonth.month,
                        )
                        .length;
                    gapToLeader = leader.wins - myWins;
                  }

                  return StreamBuilder<Map<String, Map<String, dynamic>>>(
                    stream: firestore.watchAllMonthlyOverrides(),
                    builder: (context, allOverridesSnap) {
                      final allOverrides = allOverridesSnap.data ?? {};

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          MonthSelector(
                            month: _selectedMonth,
                            onChanged: (m) =>
                                setState(() => _selectedMonth = m),
                          ),
                          const SizedBox(height: 16),
                          ..._buildChampionSection(
                            isAdmin,
                            leader,
                            isMeTheLeader,
                            gapToLeader,
                            players.isEmpty,
                            !hasActivityThisMonth && override == null,
                            !hasActivityThisMonth && override != null,
                            () => _showSetOverrideDialog(
                              context,
                              firestore,
                              players,
                              _selectedMonth,
                            ),
                            () => _showSetOverrideDialog(
                              context,
                              firestore,
                              players,
                              _selectedMonth,
                              currentPlayer: leader?.player,
                              currentWins: leader?.wins ?? 1,
                              currentLosses: leader?.losses ?? 0,
                            ),
                            () =>
                                firestore.clearMonthlyOverride(_selectedMonth),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(height: 24),
                            Text(
                              '¿Necesitas otro certificado?',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
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
                          if (me != null) ...[
                            ..._buildMyCertificateHistory(
                              _myWonMonths(entries, players, me, allOverrides),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
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
    int? gapToLeader,
    bool noPlayers,
    bool canSetOverride,
    bool isManualOverride,
    VoidCallback onSetOverride,
    VoidCallback onEditOverride,
    VoidCallback onClearOverride,
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
      // Mes sin ninguna actividad registrada: no se inventa nada, pero un
      // admin puede declarar a mano quién ganó (ej. antes de usar la app).
      if (isAdmin && canSetOverride) {
        return [
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Establecer ganador de este mes'),
            onPressed: onSetOverride,
          ),
        ];
      }
      return const [];
    }

    final label = DateFormat('MMMM yyyy', 'es').format(_selectedMonth);

    // Mensaje personal: general de quién va/fue ganando, y uno según si
    // el que ve la pantalla es quien lidera, está cerca, o va atrás.
    // Se ve igual para admins y no admins — lo único que cambia es
    // quién puede generar el certificado desde la tarjeta de arriba.
    final statusText = leader.isMonthOver
        ? 'El ganador de $label fue ${leader.player.displayName}.'
        : '${leader.player.displayName} va ganando este mes, pero el '
              'resultado todavía no está definido.';
    final String personalText;
    if (isMeTheLeader) {
      personalText = _pickMessage(_kLeaderMessages);
    } else if (gapToLeader != null && gapToLeader >= 1 && gapToLeader <= 3) {
      personalText = _pickMessage(_kCloseMessages);
    } else {
      personalText = _pickMessage(_kBehindMessages);
    }

    return [
      if (isAdmin && !leader.isMonthOver) ...[
        Text(
          'Todavía no hay ganador oficial este mes.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
      ],
      MonthlyWinnerCard(result: leader, canGenerate: isAdmin),
      if (isAdmin && isManualOverride) ...[
        const SizedBox(height: 12),
        Text(
          'Este ganador se puso a mano. Si te equivocaste, corrígelo aquí.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Corregir'),
                onPressed: onEditOverride,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restablecer'),
                onPressed: onClearOverride,
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 16),
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
    ];
  }

  /// Lista de todos los meses ya ganados por el jugador que tiene la
  /// sesión abierta, sin importar el mes que esté seleccionado arriba
  /// en el calendario — su historial completo de certificados. Siempre
  /// se muestra el título, aunque todavía no haya ninguno, para que se
  /// note que la sección existe.
  List<Widget> _buildMyCertificateHistory(List<MonthlyWinnerResult> won) {
    if (won.isEmpty) {
      return [
        const SizedBox(height: 28),
        Text(
          'Mis certificados',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Todavía no tienes ningún mes ganado. Cuando ganes uno, va a '
          'aparecer aquí.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }

    return [
      const SizedBox(height: 28),
      Text(
        'Mis certificados',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(
        'Todos los meses que has ganado, para que los tengas a la mano.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: [
            for (var i = 0; i < won.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.amber,
                ),
                title: Text(
                  'Fuiste el ganador de '
                  '${DateFormat('MMMM yyyy', 'es').format(won[i].month)}',
                ),
                subtitle: Text(
                  '${won[i].wins} ganadas · ${won[i].losses} perdidas · '
                  '${won[i].winPercentage.toStringAsFixed(0)}%',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CertificateScreen(
                      winnerName: won[i].player.fullName,
                      monthLabel: DateFormat(
                        'MMMM yyyy',
                        'es',
                      ).format(won[i].month),
                      totalScore: won[i].certificateScore,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}
