import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/round.dart';

/// Conversión entre el documento de Firestore de una ronda y la entidad
/// de dominio [Round].
class RoundDto {
  static Round fromMap(String id, Map<String, dynamic> data) {
    return Round(
      id: id,
      roundNumber: data['roundNumber'] as int,
      teamAPoints: data['teamAPoints'] as int? ?? 0,
      teamBPoints: data['teamBPoints'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  static Map<String, dynamic> toMap(Round round) => {
    'roundNumber': round.roundNumber,
    'teamAPoints': round.teamAPoints,
    'teamBPoints': round.teamBPoints,
    'createdAt': Timestamp.fromDate(round.createdAt),
  };
}
