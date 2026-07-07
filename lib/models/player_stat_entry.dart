import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerStatEntry {
  final String id;
  final String playerId;
  final bool isWin;
  final DateTime createdAt;

  PlayerStatEntry({
    required this.id,
    required this.playerId,
    required this.isWin,
    required this.createdAt,
  });

  factory PlayerStatEntry.fromMap(
    String id,
    String playerId,
    Map<String, dynamic> data,
  ) {
    return PlayerStatEntry(
      id: id,
      playerId: playerId,
      isWin: data['isWin'] as bool,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'isWin': isWin,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
