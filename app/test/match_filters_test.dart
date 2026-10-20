import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:topgolik/src/data/api_client.dart';

void main() {
  test('matches sends server-side league and live filters', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode({
          'data': <Object>[],
          'meta': {'current_page': 1, 'last_page': 1, 'total': 0},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = TopgolikApi(client: client, baseUrl: 'https://api.topgolik.com/api/v1');
    addTearDown(api.dispose);

    final page = await api.matches(
      date: DateTime(2026, 10, 21),
      leagueId: 42,
      liveOnly: true,
    );

    expect(page.items, isEmpty);
    expect(requested!.path, '/api/v1/matches');
    expect(requested!.queryParameters['date'], '2026-10-21');
    expect(requested!.queryParameters['league'], '42');
    expect(requested!.queryParameters['status'], 'live');
    expect(requested!.queryParameters['page'], '1');
  });

  test('default match search does not inject optional filters', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        '{"data":[],"meta":{"current_page":1,"last_page":1,"total":0}}',
        200,
      );
    });
    final api = TopgolikApi(client: client, baseUrl: 'https://api.topgolik.com/api/v1');
    addTearDown(api.dispose);

    await api.matches(date: DateTime(2026, 10, 21));

    expect(requested!.queryParameters.containsKey('league'), isFalse);
    expect(requested!.queryParameters.containsKey('status'), isFalse);
  });
}
