class Player {
  final String id;
  final String fullName;
  final String? shortName;
  final bool active;

  Player({
    required this.id,
    required this.fullName,
    this.shortName,
    this.active = true,
  });

  String get displayName =>
      (shortName != null && shortName!.trim().isNotEmpty) ? shortName! : fullName;

  factory Player.fromMap(String id, Map<String, dynamic> data) {
    return Player(
      id: id,
      fullName: data['fullName'] as String? ?? data['name'] as String? ?? '',
      shortName: data['shortName'] as String?,
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'shortName': shortName,
        'active': active,
      };
}
