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
}
