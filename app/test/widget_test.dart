import 'package:flutter_test/flutter_test.dart';
import 'package:topgolik/src/models/football_match.dart';

void main() {
  test('team model preserves source-provided identity and score', () {
    final team = TeamInfo.fromJson({
      'id': 42,
      'name': 'Source Team',
      'logo_url': null,
      'score': 0,
    });
    expect(team.id, 42);
    expect(team.score, 0);
    expect(team.name, 'Source Team');
  });
}
