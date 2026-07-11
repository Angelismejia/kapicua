import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory Game.fromMap(String id, Map<String, dynamic> data) {
    return Game(
      id: id,
      targetScore: data['targetScore'] as int,
      status: data['status'] as String,
      teamAPlayerIds: List<String>.from(
        (data['teamAPlayerIds'] as List?) ?? const [],
      ),
      teamBPlayerIds: List<String>.from(
        (data['teamBPlayerIds'] as List?) ?? const [],
      ),
      teamAScore: data['teamAScore'] as int? ?? 0,
      teamBScore: data['teamBScore'] as int? ?? 0,
      roundCount: data['roundCount'] as int? ?? 0,
      winner: data['winner'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      finishedAt: (data['finishedAt'] as Timestamp?)?.toDate(),
      teamALabel: data['teamALabel'] as String?,
      teamBLabel: data['teamBLabel'] as String?,
      statsResolution: data['statsResolution'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'targetScore': targetScore,
    'status': status,
    'teamAPlayerIds': teamAPlayerIds,
    'teamBPlayerIds': teamBPlayerIds,
    'teamAScore': teamAScore,
    'teamBScore': teamBScore,
    'roundCount': roundCount,
    'winner': winner,
    'createdAt': Timestamp.fromDate(createdAt),
    'finishedAt': finishedAt == null ? null : Timestamp.fromDate(finishedAt!),
    'teamALabel': teamALabel,
    'teamBLabel': teamBLabel,
    'statsResolution': statsResolution,
  };
}
