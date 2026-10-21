import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:topgolik/src/data/api_client.dart';

void main() {
  test('Premier League player search uses actual source-backed records', () async {
    Uri? requested;
    final api = TopgolikApi(
      baseUrl: 'https://api.topgolik.com/api/v1',
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(
          '{"source":"fantasy_premier_league","competition":"Premier League",'
          '"data":[{"source_id":19,"name":"Real Player","club":"Real Club",'
          '"minutes":1250,"goals":7,"assists":3,"points":85,'
          '"form":"5.2","expected_goals":"4.60","expected_assists":"2.00"}]}',
          200,
        );
      }),
    );
    addTearDown(api.dispose);

    final response = await api.premierLeaguePlayers(query: 'Real');
    expect(requested!.path, '/api/v1/players/premier-league');
    expect(requested!.queryParameters['q'], 'Real');
    expect(requested!.queryParameters['limit'], '50');
    expect(response.source, 'fantasy_premier_league');
    expect(response.players.single.id, 19);
    expect(response.players.single.goals, 7);
    expect(response.players.single.expectedGoals, '4.60');
  });

  test('missing player statistics are nullable rather than fabricated', () async {
    final api = TopgolikApi(
      baseUrl: 'https://api.topgolik.com/api/v1',
      client: MockClient((_) async => http.Response(
        '{"source":"fantasy_premier_league",'
        '"data":[{"source_id":1,"name":"Player","club":"Club",'
        '"minutes":null,"goals":null,"assists":null,"points":null,'
        '"form":null,"expected_goals":null,"expected_assists":null}]}',
        200,
      )),
    );
    addTearDown(api.dispose);
    final response = await api.premierLeaguePlayers();
    expect(response.players.single.goals, isNull);
    expect(response.players.single.expectedGoals, isNull);
  });

  test('incompatible player feeds are rejected without displaying records', () async {
    final api = TopgolikApi(
      baseUrl: 'https://api.topgolik.com/api/v1',
      client: MockClient((_) async => http.Response(
        '{"source":"unknown","data":[]}', 200,
      )),
    );
    addTearDown(api.dispose);
    await expectLater(api.premierLeaguePlayers(), throwsFormatException);
  });
}
