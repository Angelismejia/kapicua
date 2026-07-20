import '../../domain/entities/player.dart';

/// Conversión entre el documento de Firestore de un jugador y la entidad
/// de dominio [Player].
class PlayerDto {
  static Player fromMap(String id, Map<String, dynamic> data) {
    return Player(
      id: id,
      fullName: data['fullName'] as String? ?? data['name'] as String? ?? '',
      shortName: data['shortName'] as String?,
      active: data['active'] as bool? ?? true,
      authUid: data['authUid'] as String?,
      photoBase64: data['photoBase64'] as String?,
    );
  }

  static Map<String, dynamic> toMap(Player player) => {
    'fullName': player.fullName,
    'shortName': player.shortName,
    'active': player.active,
    'authUid': player.authUid,
    'photoBase64': player.photoBase64,
  };
}
