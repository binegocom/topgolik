class MatchCenterStatistic {
  const MatchCenterStatistic({required this.label, required this.value});
  final String label;
  final String value;

  factory MatchCenterStatistic.fromJson(Map<String, dynamic> json) =>
      MatchCenterStatistic(
        label: json['label'] as String,
        value: json['value'] as String,
      );
}

class MatchCenterPlayer {
  const MatchCenterPlayer({
    required this.name, this.position, this.starter,
  });
  final String name;
  final String? position;
  final bool? starter;

  factory MatchCenterPlayer.fromJson(Map<String, dynamic> json) =>
      MatchCenterPlayer(
        name: json['name'] as String,
        position: json['position'] as String?,
        starter: json['starter'] as bool?,
      );
}

class MatchCenterEvent {
  const MatchCenterEvent({
    required this.title, this.minute, this.description,
  });
  final String title;
  final String? minute;
  final String? description;

  factory MatchCenterEvent.fromJson(Map<String, dynamic> json) =>
      MatchCenterEvent(
        title: json['title'] as String,
        minute: json['minute'] as String?,
        description: json['description'] as String?,
      );
}

class MatchCenterData {
  const MatchCenterData({
    required this.source,
    required this.supported,
    required this.homeStats,
    required this.awayStats,
    required this.homePlayers,
    required this.awayPlayers,
    required this.events,
  });

  final String source;
  final bool supported;
  final List<MatchCenterStatistic> homeStats;
  final List<MatchCenterStatistic> awayStats;
  final List<MatchCenterPlayer> homePlayers;
  final List<MatchCenterPlayer> awayPlayers;
  final List<MatchCenterEvent> events;

  static List<T> _readList<T>(
    Object? value, T Function(Map<String, dynamic>) parser,
  ) {
    if (value is! List) {
      throw const FormatException('Missing match center data list.');
    }
    return value
        .map((item) => parser(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  factory MatchCenterData.fromJson(Map<String, dynamic> json) {
    final statistics = json['statistics'];
    final lineups = json['lineups'];
    if (statistics is! Map<String, dynamic> ||
        lineups is! Map<String, dynamic>) {
      throw const FormatException('Missing match center fields.');
    }
    return MatchCenterData(
      source: json['source'] as String,
      supported: json['supported'] as bool,
      homeStats: _readList(statistics['home'], MatchCenterStatistic.fromJson),
      awayStats: _readList(statistics['away'], MatchCenterStatistic.fromJson),
      homePlayers: _readList(lineups['home'], MatchCenterPlayer.fromJson),
      awayPlayers: _readList(lineups['away'], MatchCenterPlayer.fromJson),
      events: _readList(json['events'], MatchCenterEvent.fromJson),
    );
  }
}
