class Player {
  final String id;
  final String fullName;
  final String? shortName;
  final bool active;
  final String? authUid;
  final String? photoUrl;

  Player({
    required this.id,
    required this.fullName,
    this.shortName,
    this.active = true,
    this.authUid,
    this.photoUrl,
  });

  String get displayName => (shortName != null && shortName!.trim().isNotEmpty)
      ? shortName!
      : fullName;

  factory Player.fromMap(String id, Map<String, dynamic> data) {
    return Player(
      id: id,
      fullName: data['fullName'] as String? ?? data['name'] as String? ?? '',
      shortName: data['shortName'] as String?,
      active: data['active'] as bool? ?? true,
      authUid: data['authUid'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'fullName': fullName,
    'shortName': shortName,
    'active': active,
    'authUid': authUid,
    'photoUrl': photoUrl,
  };
}
