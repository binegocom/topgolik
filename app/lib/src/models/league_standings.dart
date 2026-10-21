class StandingsTeam {
  const StandingsTeam({required this.id, required this.name, this.logoUrl});
  final int id;
  final String name;
  final String? logoUrl;

  factory StandingsTeam.fromJson(Map<String, dynamic> json) => StandingsTeam(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        logoUrl: json['logo_url'] as String?,
      );
}

class StandingRow {
  const StandingRow({
    required this.position,
    required this.team,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
  });

  final int position;
  final StandingsTeam team;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;

  factory StandingRow.fromJson(Map<String, dynamic> json) => StandingRow(
        position: (json['position'] as num).toInt(),
        team: StandingsTeam.fromJson(json['team'] as Map<String, dynamic>),
        played: (json['played'] as num).toInt(),
        won: (json['won'] as num).toInt(),
        drawn: (json['drawn'] as num).toInt(),
        lost: (json['lost'] as num).toInt(),
        goalsFor: (json['goals_for'] as num).toInt(),
        goalsAgainst: (json['goals_against'] as num).toInt(),
        goalDifference: (json['goal_difference'] as num).toInt(),
        points: (json['points'] as num).toInt(),
      );
}

class LeagueStandings {
  const LeagueStandings({
    required this.season,
    required this.matchesCounted,
    required this.official,
    required this.complete,
    required this.rows,
  });

  final int season;
  final int matchesCounted;
  final bool official;
  final bool complete;
  final List<StandingRow> rows;

  factory LeagueStandings.fromJson(Map<String, dynamic> json) {
    if (json['data'] is! List) {
      throw const FormatException('Invalid standings response.');
    }
    return LeagueStandings(
      season: (json['season'] as num).toInt(),
      matchesCounted: (json['matches_counted'] as num).toInt(),
      official: json['official'] as bool,
      complete: json['complete'] as bool,
      rows: (json['data'] as List)
          .map((item) => StandingRow.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
