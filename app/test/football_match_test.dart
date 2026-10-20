import 'package:flutter_test/flutter_test.dart';
import 'package:topgolik/src/models/football_match.dart';

void main() {
  test('parses a server-provided match with scores and times', () {
    final match = FootballMatch.fromJson({
      'id': 1,
      'league': {'id': 2, 'name': 'Test League', 'country': null},
      'home': {'id': 3, 'name': 'Home', 'logo_url': null, 'score': 2},
      'away': {'id': 4, 'name': 'Away', 'logo_url': null, 'score': 1},
      'starts_at': '2026-10-21T18:00:00+00:00',
      'updated_at': '2026-10-21T19:00:00+00:00',
      'status': 'live',
      'status_detail': '70',
      'source': 'test',
    });
    expect(match.isLive, isTrue);
    expect(match.hasScore, isTrue);
    expect(match.home.score, 2);
  });
}
