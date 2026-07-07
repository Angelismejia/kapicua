import 'package:cloud_firestore/cloud_firestore.dart';

class Round {
  final String id;
  final int roundNumber;
  final int teamAPoints;
  final int teamBPoints;
  final DateTime createdAt;

  Round({
    required this.id,
    required this.roundNumber,
    required this.teamAPoints,
    required this.teamBPoints,
    required this.createdAt,
  });

  factory Round.fromMap(String id, Map<String, dynamic> data) {
    return Round(
      id: id,
      roundNumber: data['roundNumber'] as int,
      teamAPoints: data['teamAPoints'] as int? ?? 0,
      teamBPoints: data['teamBPoints'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'roundNumber': roundNumber,
    'teamAPoints': teamAPoints,
    'teamBPoints': teamBPoints,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
