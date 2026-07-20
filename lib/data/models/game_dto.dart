import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/game.dart';

/// Conversión entre el documento de Firestore de una partida y la
/// entidad de dominio [Game].
class GameDto {
  static Game fromMap(String id, Map<String, dynamic> data) {
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

  static Map<String, dynamic> toMap(Game game) => {
    'targetScore': game.targetScore,
    'status': game.status,
    'teamAPlayerIds': game.teamAPlayerIds,
    'teamBPlayerIds': game.teamBPlayerIds,
    'teamAScore': game.teamAScore,
    'teamBScore': game.teamBScore,
    'roundCount': game.roundCount,
    'winner': game.winner,
    'createdAt': Timestamp.fromDate(game.createdAt),
    'finishedAt': game.finishedAt == null
        ? null
        : Timestamp.fromDate(game.finishedAt!),
    'teamALabel': game.teamALabel,
    'teamBLabel': game.teamBLabel,
    'statsResolution': game.statsResolution,
  };
}
