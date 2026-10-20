import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/api_client.dart';
import '../models/football_match.dart';
import '../models/team_search.dart';
import 'match_detail_screen.dart';
import 'topgolik_app.dart';

class TeamMatchesScreen extends StatefulWidget {
  const TeamMatchesScreen({super.key, required this.api, required this.team});
  final TopgolikApi api;
  final SearchTeam team;

  @override
  State<TeamMatchesScreen> createState() => _TeamMatchesScreenState();
}

class _TeamMatchesScreenState extends State<TeamMatchesScreen> {
  List<FootballMatch> _matches = [];
  int _page = 0;
  int _lastPage = 1;
  bool _loading = true;
  bool _busy = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (_busy) return;
    _busy = true;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final result = await widget.api.teamMatches(
        teamId: widget.team.id,
        page: append ? _page + 1 : 1,
      );
      if (!mounted) return;
      setState(() {
        _matches = append ? [..._matches, ...result.items] : result.items;
        _page = result.currentPage;
        _lastPage = result.lastPage;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      _busy = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.team.name)),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(t.teamMatches,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            if (_loading && _matches.isEmpty)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error && _matches.isEmpty)
              Column(
                children: [
                  Text(t.connectionError),
                  OutlinedButton(onPressed: () => _load(), child: Text(t.retry)),
                ],
              )
            else if (_matches.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.noMatches, textAlign: TextAlign.center),
              )
            else
              for (final match in _matches)
                Card(
                  color: TopgolikApp.panel,
                  child: ListTile(
                    title: Text('${match.home.name} – ${match.away.name}'),
                    subtitle: Text(match.league.name),
                    trailing: Text(
                      match.hasScore
                          ? '${match.home.score} : ${match.away.score}'
                          : TimeOfDay.fromDateTime(match.startsAt).format(context),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MatchDetailScreen(
                          api: widget.api,
                          matchId: match.id,
                        ),
                      ),
                    ),
                  ),
                ),
            if (_page < _lastPage || (_error && _matches.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _load(append: true),
                  child: Text(_error ? t.retry : t.seeAll),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
