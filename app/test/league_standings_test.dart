import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:topgolik/src/data/api_client.dart';

void main() {
  test('standings API preserves verified scores and labels the table nonofficial', () async {
    Uri? captured;
    final api = TopgolikApi(
      baseUrl: 'https://api.topgolik.com/api/v1',
      client: MockClient((request) async {
        captured = request.url;
        return http.Response(
          '{"league":{"id":5,"name":"Sample League","country":"Turkey"},'
          '"season":2026,"season_start_month":7,'
          '"source":"derived_from_stored_final_scores",'
          '"official":false,"complete":false,"matches_counted":2,'
          '"data":[{"position":1,"team":{"id":50,"name":"Example FC","logo_url":null},'
          '"played":2,"won":1,"drawn":1,"lost":0,"goals_for":4,'
          '"goals_against":2,"goal_difference":2,"points":4}]}',
          200,
        );
      }),
    );
    addTearDown(api.dispose);

    final data = await api.standings(leagueId: 5, season: 2026);
    expect(captured!.path, '/api/v1/leagues/5/standings');
    expect(captured!.queryParameters['season'], '2026');
    expect(captured!.queryParameters['season_start_month'], '7');
    expect(data.official, isFalse);
    expect(data.complete, isFalse);
    expect(data.matchesCounted, 2);
    expect(data.rows.single.team.name, 'Example FC');
    expect(data.rows.single.points, 4);
    expect(data.rows.single.goalDifference, 2);
  });

  test('empty provisional table remains empty instead of inventing a ranking', () async {
    final api = TopgolikApi(
      baseUrl: 'https://api.topgolik.com/api/v1',
      client: MockClient((_) async => http.Response(
        '{"season":2026,"matches_counted":0,"official":false,"complete":false,"data":[]}',
        200,
      )),
    );
    addTearDown(api.dispose);
    final result = await api.standings(leagueId: 7, season: 2026);
    expect(result.rows, isEmpty);
  });
}
