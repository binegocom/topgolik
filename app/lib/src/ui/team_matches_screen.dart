import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/api_client.dart';
import '../models/football_match.dart';
import '../models/team_search.dart';
import 'design/topgolik_ui.dart';
import 'match_detail_screen.dart';

class TeamMatchesScreen extends StatefulWidget {
  const TeamMatchesScreen({super.key, required this.api, required this.team});
  final TopgolikApi api;
  final SearchTeam team;

  @override
  State<TeamMatchesScreen> createState() => _TeamMatchesScreenState();
}

class _TeamMatchesScreenState extends State<TeamMatchesScreen> {
  List<FootballMatch> _matches = [];
  int _tab = 0;
  int _page = 0;
  int _lastPage = 1;
  bool _busy = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = false; });
    try {
      final result = await widget.api.teamMatches(
        teamId: widget.team.id, page: append ? _page + 1 : 1,
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tabs = [t.overview, t.matches, t.lineups, t.statistics, t.news];
    final showMatches = _tab <= 1;

    return Scaffold(
      appBar: AppBar(title: Text(widget.team.name)),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: StadiumColors.border),
                gradient: const LinearGradient(
                  colors: [Color(0xFF133C2B), Color(0xFF071C2A), StadiumColors.background],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Column(children: [
                TeamCrest(url: widget.team.logoUrl, size: 67),
                const SizedBox(height: 12),
                Text(widget.team.name, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < tabs.length; i++) ...[
                  TopgolikPill(
                    label: tabs[i], selected: _tab == i,
                    onPressed: () => setState(() => _tab = i),
                  ),
                  const SizedBox(width: 7),
                ],
              ]),
            ),
            const SizedBox(height: 18),
            if (!showMatches)
              TopgolikPanel(
                child: EmptyFootballState(title: tabs[_tab], details: t.dataUnavailable),
              )
            else ...[
              SectionHeader(title: t.teamMatches, icon: Icons.calendar_month_outlined),
              const SizedBox(height: 10),
              if (_busy && _matches.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(35),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error && _matches.isEmpty)
                EmptyFootballState(
                  title: t.connectionError,
                  onRetry: () => _load(),
                  retryLabel: t.retry,
                )
              else if (_matches.isEmpty)
                EmptyFootballState(title: t.noMatches)
              else
                TopgolikPanel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final match in _matches)
                      FootballMatchTile(
                        match: match,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MatchDetailScreen(
                              api: widget.api,
                              matchId: match.id,
                            ),
                          ),
                        ),
                      ),
                  ]),
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
          ],
        ),
      ),
    );
  }
}
