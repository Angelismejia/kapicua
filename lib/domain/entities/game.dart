class Game {
  final String id;
  final int targetScore;
  final String status; // 'in_progress' | 'finished'
  final List<String> teamAPlayerIds;
  final List<String> teamBPlayerIds;
  final int teamAScore;
  final int teamBScore;
  final String? winner; // 'A' | 'B'
  final int roundCount;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final String? teamALabel;
  final String? teamBLabel;
  // null = todavia no se decidio si se agrega a Estadisticas o se
  // ignora; 'added' = ya se le sumo la ganada/perdida a cada jugador;
  // 'ignored' = se descarto a proposito (ej. una partida de prueba) y
  // no debe volver a sugerirse.
  final String? statsResolution;

  Game({
    required this.id,
    required this.targetScore,
    required this.status,
    required this.teamAPlayerIds,
    required this.teamBPlayerIds,
    required this.createdAt,
    this.teamAScore = 0,
    this.teamBScore = 0,
    this.roundCount = 0,
    this.winner,
    this.finishedAt,
    this.teamALabel,
    this.teamBLabel,
    this.statsResolution,
  });

  bool get isFinished => status == 'finished';
}
