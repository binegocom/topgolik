import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/football_match.dart';

class MatchPage {
  const MatchPage({required this.items, required this.currentPage, required this.lastPage});
  final List<FootballMatch> items;
  final int currentPage;
  final int lastPage;
}

class TopgolikApi {
  TopgolikApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? const String.fromEnvironment(
          'TOPGOLIK_API_URL',
          defaultValue: 'https://api.topgolik.com/api/v1',
        );

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> _get(String path, [Map<String, String> params = const {}]) async {
    final base = Uri.parse('$_baseUrl$path');
    if (base.scheme != 'https' && !(base.scheme == 'http' && {'127.0.0.1', '10.0.2.2', 'localhost'}.contains(base.host))) {
      throw const FormatException('An HTTPS API endpoint is required.');
    }
    final uri = base.replace(queryParameters: params.isEmpty ? null : params);
    final response = await _client.get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw http.ClientException('API returned ${response.statusCode}', uri);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) { throw const FormatException('Invalid API response.'); }
    return decoded;
  }

  Future<MatchPage> matches({
    required DateTime date,
    int page = 1,
    int? leagueId,
    bool liveOnly = false,
  }) async {
    final local = DateTime(date.year, date.month, date.day);
    final formatted = '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final data = await _get('/matches', {
      'date': formatted,
      'offset_minutes': local.timeZoneOffset.inMinutes.toString(),
      'page': page.toString(),
      if (leagueId != null) 'league': leagueId.toString(),
      if (liveOnly) 'status': 'live',
    });
    final entries = data['data'];
    final meta = data['meta'];
    if (entries is! List || meta is! Map<String, dynamic>) {
      throw const FormatException('Invalid match list response.');
    }
    return MatchPage(
      items: entries.map((value) => FootballMatch.fromJson(value as Map<String, dynamic>)).toList(),
      currentPage: (meta['current_page'] as num).toInt(),
      lastPage: (meta['last_page'] as num).toInt(),
    );
  }

  Future<List<LeagueInfo>> leagues() async {
    final data = await _get('/leagues');
    final entries = data['data'];
    if (entries is! List) { throw const FormatException('Invalid league response.'); }
    return entries.map((v) => LeagueInfo.fromJson(v as Map<String, dynamic>)).toList();
  }

  Future<FootballMatch> match(int id) async {
    final data = await _get('/matches/$id');
    return FootballMatch.fromJson(data['data'] as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}
