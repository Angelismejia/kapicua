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
}
