import 'package:cloud_firestore/cloud_firestore.dart';

class Round {
  final String id;
  final int roundNumber;
  final Map<String, int> points; // playerId -> puntos ganados esa ronda
  final DateTime createdAt;

  Round({
    required this.id,
    required this.roundNumber,
    required this.points,
    required this.createdAt,
  });

  factory Round.fromMap(String id, Map<String, dynamic> data) {
    return Round(
      id: id,
      roundNumber: data['roundNumber'] as int,
      points: Map<String, int>.from(data['points'] as Map),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'roundNumber': roundNumber,
        'points': points,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
