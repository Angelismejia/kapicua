import 'package:cloud_firestore/cloud_firestore.dart';

class Game {
  final String id;
  final int targetScore;
  final String status; // 'in_progress' | 'finished'
  final String? winnerId;
  final List<String> participantIds;
  final Map<String, int> scores; // playerId -> total acumulado
  final int roundCount;
  final DateTime createdAt;
  final DateTime? finishedAt;

  Game({
    required this.id,
    required this.targetScore,
    required this.status,
    required this.participantIds,
    required this.scores,
    required this.createdAt,
    this.roundCount = 0,
    this.winnerId,
    this.finishedAt,
  });

  bool get isFinished => status == 'finished';

  factory Game.fromMap(String id, Map<String, dynamic> data) {
    return Game(
      id: id,
      targetScore: data['targetScore'] as int,
      status: data['status'] as String,
      winnerId: data['winnerId'] as String?,
      participantIds: List<String>.from(data['participantIds'] as List),
      scores: Map<String, int>.from(data['scores'] as Map),
      roundCount: data['roundCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      finishedAt: (data['finishedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'targetScore': targetScore,
        'status': status,
        'winnerId': winnerId,
        'participantIds': participantIds,
        'scores': scores,
        'roundCount': roundCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'finishedAt': finishedAt == null ? null : Timestamp.fromDate(finishedAt!),
      };
}
