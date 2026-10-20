import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:topgolik/src/data/api_client.dart';

void main() {
  test('featured teams retain server order and never invent missing team IDs', () async {
    final names = [
      'AmedSpor', 'Vanspor FK', 'Mardin 1969 Spor', 'Batman Petrol Spor',
      'Muş Spor Kulübü', '12 Bingölspor', 'Galatasaray', 'Fenerbahçe', 'Beşiktaş',
    ];
    final requests = <Uri>[];
    final api = TopgolikApi(
      baseUrl: 'https://api.topgolik.com/api/v1',
      client: MockClient((req) async {
        requests.add(req.url);
        return http.Response(jsonEncode({
          'featured': [for (final name in names) {'name': name, 'team': null}],
          'results': [],
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
    addTearDown(api.dispose);

    final result = await api.searchTeams();
    expect(requests.single.path, '/api/v1/search/teams');
    expect(result.featured.map((item) => item.name).toList(), names);
    expect(result.featured.every((item) => item.team == null), isTrue);
  });

  test('real team lookup and paginated fixtures query backend', () async {
    final urls = <Uri>[];
    final api = TopgolikApi(
      baseUrl: 'https://api.topgolik.com/api/v1',
      client: MockClient((request) async {
        urls.add(request.url);
        if (request.url.path.contains('search/teams')) {
          return http.Response(
            '{"featured":[],"results":[{"id":7,"name":"Amedspor","provider":"espn","logo_url":null}]}',
            200,
          );
        }
        return http.Response(
          '{"data":[],"meta":{"current_page":2,"last_page":2,"total":31}}',
          200,
        );
      }),
    );
    addTearDown(api.dispose);

    final result = await api.searchTeams(query: 'Amed');
    expect(result.results.single.id, 7);
    expect(urls.first.queryParameters['q'], 'Amed');

    final fixtures = await api.teamMatches(teamId: 7, page: 2);
    expect(fixtures.currentPage, 2);
    expect(urls.last.path, '/api/v1/teams/7/matches');
    expect(urls.last.queryParameters['page'], '2');
  });
}
