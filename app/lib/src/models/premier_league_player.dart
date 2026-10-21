class PremierLeaguePlayer {
  const PremierLeaguePlayer({
    required this.id, required this.name, required this.club,
    this.minutes, this.goals, this.assists, this.points,
    this.form, this.expectedGoals, this.expectedAssists,
  });

  final int id;
  final String name;
  final String club;
  final int? minutes;
  final int? goals;
  final int? assists;
  final int? points;
  final String? form;
  final String? expectedGoals;
  final String? expectedAssists;

  factory PremierLeaguePlayer.fromJson(Map<String, dynamic> json) =>
      PremierLeaguePlayer(
        id: (json['source_id'] as num).toInt(),
        name: json['name'] as String,
        club: json['club'] as String,
        minutes: (json['minutes'] as num?)?.toInt(),
        goals: (json['goals'] as num?)?.toInt(),
        assists: (json['assists'] as num?)?.toInt(),
        points: (json['points'] as num?)?.toInt(),
        form: json['form'] as String?,
        expectedGoals: json['expected_goals'] as String?,
        expectedAssists: json['expected_assists'] as String?,
      );
}

class PlayerSearchResponse {
  const PlayerSearchResponse({required this.source, required this.players});
  final String source;
  final List<PremierLeaguePlayer> players;

  factory PlayerSearchResponse.fromJson(Map<String, dynamic> json) {
    if (json['source'] != 'fantasy_premier_league' || json['data'] is! List) {
      throw const FormatException('Unsupported player source response.');
    }
    return PlayerSearchResponse(
      source: json['source'] as String,
      players: (json['data'] as List)
          .map((item) => PremierLeaguePlayer.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
