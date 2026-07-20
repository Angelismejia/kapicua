import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/player_stat_entry.dart';

/// Conversión entre el documento de Firestore de una ganada/perdida y la
/// entidad de dominio [PlayerStatEntry].
class PlayerStatEntryDto {
  static PlayerStatEntry fromMap(
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

  static Map<String, dynamic> toMap(PlayerStatEntry entry) => {
    'isWin': entry.isWin,
    'createdAt': Timestamp.fromDate(entry.createdAt),
  };
}
