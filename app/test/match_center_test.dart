import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:topgolik/src/data/api_client.dart';

void main() {
  test('match center maps source-backed statistics', () async {
    Uri? requested;
    final api = TopgolikApi(
      baseUrl: 'https://api.topgolik.com/api/v1',
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(
          '{"source":"espn","supported":true,'
          '"statistics":{"home":[{"label":"Possession","value":"58%"}],"away":[]},'
          '"lineups":{"home":[{"name":"First Player","position":"GK","starter":true}],"away":[]},'
          '"events":[{"minute":"35","title":"Goal","description":null}]}',
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final data = await api.matchCenter(23);
    expect(requested!.path, '/api/v1/matches/23/center');
    expect(data.supported, true);
    expect(data.homeStats.single.value, '58%');
    expect(data.homePlayers.single.starter, true);
    expect(data.events.single.title, 'Goal');
    expect(data.awayStats, isEmpty);
  });

  test('unavailable upstream returns explicit unsupported state', () async {
    final api = TopgolikApi(
      baseUrl: 'https://api.topgolik.com/api/v1',
      client: MockClient((_) async => http.Response(
        '{"source":"openligadb","supported":false,'
        '"statistics":{"home":[],"away":[]},'
        '"lineups":{"home":[],"away":[]},"events":[]}', 200,
      )),
    );
    addTearDown(api.dispose);
    final data = await api.matchCenter(50);
    expect(data.supported, false);
    expect(data.homePlayers, isEmpty);
    expect(data.events, isEmpty);
  });

  test('invalid upstream payload never renders an imaginary squad', () async {
    final api = TopgolikApi(
      baseUrl: 'https://api.topgolik.com/api/v1',
      client: MockClient((_) async => http.Response(
        '{"source":"espn","supported":true,"statistics":[]}', 200,
      )),
    );
    addTearDown(api.dispose);
    await expectLater(api.matchCenter(20), throwsFormatException);
  });
}
