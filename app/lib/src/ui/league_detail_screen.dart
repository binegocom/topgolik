import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/api_client.dart';
import '../models/football_match.dart';
import '../models/league_standings.dart';
import 'design/topgolik_ui.dart';
import 'match_detail_screen.dart';

class LeagueDetailScreen extends StatefulWidget {
  const LeagueDetailScreen({super.key, required this.api, required this.league});
  final TopgolikApi api;
  final LeagueInfo league;

  @override
  State<LeagueDetailScreen> createState() => _LeagueDetailScreenState();
}

class _LeagueDetailScreenState extends State<LeagueDetailScreen> {
  DateTime _date = DateTime.now();
  int _tab = 0;
  late Future<LeagueStandings> _standings;
  int _page = 0;
  int _lastPage = 1;
  int _serial = 0;
  bool _busy = false;
  bool _error = false;
  List<FootballMatch> _matches = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadStandings();
  }

  Future<void> _load({bool append = false}) async {
    if (_busy && append) return;
    final serial = ++_serial;
    final date = _date;
    setState(() {
      _busy = true;
      _error = false;
      if (!append) {
        _matches = [];
        _page = 0;
      }
    });
    try {
      final result = await widget.api.matches(
        date: date, page: append ? _page + 1 : 1, leagueId: widget.league.id,
      );
      if (!mounted || serial != _serial) return;
      setState(() {
        _matches = append ? [..._matches, ...result.items] : result.items;
        _page = result.currentPage;
        _lastPage = result.lastPage;
      });
    } catch (_) {
      if (mounted && serial == _serial) setState(() => _error = true);
    } finally {
      if (mounted && serial == _serial) setState(() => _busy = false);
    }
  }

  void _loadStandings() {
    final now = DateTime.now();
    _standings = widget.api.standings(
      leagueId: widget.league.id,
      season: now.month < 7 ? now.year - 1 : now.year,
    );
  }

  void _shift(int byDays) {
    setState(() => _date = DateTime(_date.year, _date.month, _date.day + byDays));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.league.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TopgolikPanel(
            child: Column(children: [
              const Icon(Icons.emoji_events_rounded, color: StadiumColors.green, size: 38),
              const SizedBox(height: 10),
              Text(widget.league.name, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              if (widget.league.country != null) ...[
                const SizedBox(height: 4),
                Text(widget.league.country!, style: const TextStyle(color: StadiumColors.muted)),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            TopgolikPill(label: t.leagueFixtures, selected: _tab == 0,
                onPressed: () => setState(() => _tab = 0)),
            const SizedBox(width: 8),
            TopgolikPill(label: t.standings, selected: _tab == 1,
                onPressed: () => setState(() => _tab = 1)),
          ]),
          const SizedBox(height: 14),
          if (_tab == 1)
            _standingsPanel(t)
          else ...[
            TopgolikPanel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
                Expanded(child: Text(
                    MaterialLocalizations.of(context).formatMediumDate(_date),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: StadiumColors.green),
                  )),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
              ]),
            ),
            const SizedBox(height: 12),
            if (_busy && _matches.isEmpty)
              const Padding(padding: EdgeInsets.all(45), child: Center(child: CircularProgressIndicator()))
            else if (_error && _matches.isEmpty)
              EmptyFootballState(title: t.connectionError, onRetry: _load, retryLabel: t.retry)
            else if (_matches.isEmpty)
              EmptyFootballState(title: t.noMatches)
            else
              TopgolikPanel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final match in _matches)
                    FootballMatchTile(
                      match: match,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => MatchDetailScreen(api: widget.api, matchId: match.id),
                      )),
                    ),
                ]),
              ),
            if (_page < _lastPage)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _load(append: true),
                  child: Text(t.seeAll),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _standingsPanel(AppLocalizations t) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TopgolikPanel(
        child: Text(t.standingsProvisional,
          style: const TextStyle(fontSize: 12, color: StadiumColors.muted)),
      ),
      const SizedBox(height: 12),
      FutureBuilder<LeagueStandings>(
        future: _standings,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return EmptyFootballState(
              title: t.connectionError,
              retryLabel: t.retry,
              onRetry: () => setState(_loadStandings),
            );
          }
          final data = snapshot.data!;
          if (data.rows.isEmpty) {
            return EmptyFootballState(title: t.standingsUnavailable);
          }
          return TopgolikPanel(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Text(
                '${t.standingsCounted}: ${data.matchesCounted}',
                style: const TextStyle(color: StadiumColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(child: SizedBox.shrink()),
                _metric(t.standingsPlayed),
                _metric(t.standingsDifference),
                _metric(t.standingsPoints),
              ]),
              const Divider(color: StadiumColors.border),
              for (final row in data.rows) ...[
                Row(children: [
                  SizedBox(width: 27, child: Text(
                    '${row.position}', textAlign: TextAlign.center,
                    style: const TextStyle(color: StadiumColors.muted))),
                  TeamCrest(url: row.team.logoUrl, size: 24),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    row.team.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  )),
                  _metric('${row.played}'),
                  _metric('${row.goalDifference}'),
                  _metric('${row.points}', highlighted: true),
                ]),
                const Divider(color: StadiumColors.border, height: 20),
              ],
            ]),
          );
        },
      ),
    ],
  );

  Widget _metric(String label, {bool highlighted = false}) => SizedBox(
    width: 33,
    child: Text(label, textAlign: TextAlign.center, style: TextStyle(
      fontSize: 11,
      color: highlighted ? StadiumColors.green : StadiumColors.muted,
      fontWeight: highlighted ? FontWeight.w800 : FontWeight.w500,
    )),
  );

}
