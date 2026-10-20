class SearchTeam {
  const SearchTeam({required this.id, required this.name, required this.provider, this.logoUrl});
  final int id;
  final String name;
  final String provider;
  final String? logoUrl;

  factory SearchTeam.fromJson(Map<String, dynamic> json) => SearchTeam(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    provider: json['provider'] as String,
    logoUrl: json['logo_url'] as String?,
  );
}

class FeaturedTeam {
  const FeaturedTeam({required this.name, this.team});
  final String name;
  final SearchTeam? team;
  factory FeaturedTeam.fromJson(Map<String, dynamic> json) => FeaturedTeam(
    name: json['name'] as String,
    team: json['team'] == null
        ? null
        : SearchTeam.fromJson(json['team'] as Map<String, dynamic>),
  );
}

class TeamSearchResponse {
  const TeamSearchResponse({required this.featured, required this.results});
  final List<FeaturedTeam> featured;
  final List<SearchTeam> results;
  factory TeamSearchResponse.fromJson(Map<String, dynamic> json) {
    final featured = json['featured'], results = json['results'];
    if (featured is! List || results is! List) {
      throw const FormatException('Invalid search response.');
    }
    return TeamSearchResponse(
      featured: featured.map((v) => FeaturedTeam.fromJson(v as Map<String, dynamic>)).toList(),
      results: results.map((v) => SearchTeam.fromJson(v as Map<String, dynamic>)).toList(),
    );
  }
}
