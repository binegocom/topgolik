class TeamInfo {
  const TeamInfo({required this.id, required this.name, this.logoUrl, this.score});
  final int id;
  final String name;
  final String? logoUrl;
  final int? score;

  factory TeamInfo.fromJson(Map<String, dynamic> json) => TeamInfo(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        logoUrl: json['logo_url'] as String?,
        score: (json['score'] as num?)?.toInt(),
      );
}

class LeagueInfo {
  const LeagueInfo({required this.id, required this.name, this.country});
  final int id;
  final String name;
  final String? country;

  factory LeagueInfo.fromJson(Map<String, dynamic> json) => LeagueInfo(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        country: json['country'] as String?,
      );
}

class FootballMatch {
  const FootballMatch({
    required this.id,
    required this.league,
    required this.home,
    required this.away,
    required this.startsAt,
    required this.updatedAt,
    required this.status,
    this.statusDetail,
    required this.source,
  });

  final int id;
  final LeagueInfo league;
  final TeamInfo home;
  final TeamInfo away;
  final DateTime startsAt;
  final DateTime updatedAt;
  final String status;
  final String? statusDetail;
  final String source;
  bool get isLive => status == 'live';
  bool get isFinished => status == 'finished';
  bool get hasScore => home.score != null && away.score != null;

  factory FootballMatch.fromJson(Map<String, dynamic> json) => FootballMatch(
        id: (json['id'] as num).toInt(),
        league: LeagueInfo.fromJson(json['league'] as Map<String, dynamic>),
        home: TeamInfo.fromJson(json['home'] as Map<String, dynamic>),
        away: TeamInfo.fromJson(json['away'] as Map<String, dynamic>),
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
        status: json['status'] as String,
        statusDetail: json['status_detail'] as String?,
        source: json['source'] as String,
      );
}
