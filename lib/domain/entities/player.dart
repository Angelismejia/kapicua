class Player {
  final String id;
  final String fullName;
  final String? shortName;
  final bool active;
  final String? authUid;

  /// Foto de perfil guardada como texto base64 directo en el documento
  /// (en vez de un archivo en Storage, que requiere plan de pago). Por
  /// eso la imagen se comprime a un tamaño chico antes de guardarla.
  final String? photoBase64;

  Player({
    required this.id,
    required this.fullName,
    this.shortName,
    this.active = true,
    this.authUid,
    this.photoBase64,
  });

  String get displayName => (shortName != null && shortName!.trim().isNotEmpty)
      ? shortName!
      : fullName;
}
