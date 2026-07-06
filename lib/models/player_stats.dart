import 'player.dart';

class PlayerStats {
  final Player player;
  final int gamesWon;
  final int gamesLost;

  PlayerStats({required this.player, required this.gamesWon, required this.gamesLost});

  int get gamesPlayed => gamesWon + gamesLost;

  double get winPercentage => gamesPlayed == 0 ? 0 : (gamesWon / gamesPlayed) * 100;
}
