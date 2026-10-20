import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/api_client.dart';
import '../data/favorite_store.dart';
import '../models/football_match.dart';
import 'match_detail_screen.dart';
import 'topgolik_app.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _api = TopgolikApi();
  final _favorites = FavoriteStore();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  DateTime _date = DateTime.now();
  List<FootballMatch> _matches = [];
  List<LeagueInfo> _leagues = [];
  Set<int> _favoriteIds = {};
  int _page = 1;
  int _lastPage = 1;
  int _requestId = 0;
  int _tab = 0;
  int? _leagueId;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocalData();
    _loadMatches();
    _loadLeagues();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_resumed && !_busy) { _loadMatches(silent: true); }
    });
  }

  Future<void> _loadLocalData() async {
    try {
      final ids = await _favorites.load();
      if (mounted) { setState(() => _favoriteIds = ids); }
    } catch (_) {
      // Bookmarks remain usable in memory when device storage is unavailable.
    }
  }

  Future<void> _loadLeagues() async {
    try {
      final leagues = await _api.leagues();
      if (mounted) { setState(() => _leagues = leagues); }
    } catch (_) {
      // The match list remains available even if the league catalog is offline.
    }
  }

  Future<void> _loadMatches({bool silent = false, bool append = false}) async {
    if (_busy && silent) { return; }
    final requestId = ++_requestId;
    final page = append ? _page + 1 : 1;
    final date = _date;
    _busy = true;
    if (!silent && mounted) { setState(() { _loading = true; _error = null; }); }
    try {
      final result = await _api.matches(date: date, page: page);
      if (!mounted || requestId != _requestId) { return; }
      setState(() {
        _matches = append ? [..._matches, ...result.items] : result.items;
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) { return; }
      setState(() { _loading = false; _error = 'network'; });
    } finally {
      _busy = false;
    }
  }

  void _changeDate(int days) {
    setState(() {
      _date = DateTime(_date.year, _date.month, _date.day + days);
      _matches = [];
      _page = _lastPage = 1;
      _error = null;
    });
    if (_scrollController.hasClients) { _scrollController.jumpTo(0); }
    _loadMatches();
  }

  Future<void> _toggleFavorite(int id) async {
    final previous = Set<int>.from(_favoriteIds);
    final next = Set<int>.from(previous);
    if (!next.add(id)) { next.remove(id); }
    setState(() => _favoriteIds = next);
    try { await _favorites.save(next); } catch (_) {
      if (mounted) { setState(() => _favoriteIds = previous); }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) { _loadMatches(silent: true); }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _scrollController.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final selected = _matches.where((m) =>
        (_leagueId == null || m.league.id == _leagueId) &&
        (_tab != 1 || m.isLive) &&
        (_tab != 2 || _favoriteIds.contains(m.id))).toList();
    final groups = <int, List<FootballMatch>>{};
    for (final match in selected) {
      groups.putIfAbsent(match.league.id, () => []).add(match);
    }
    final leagueById = {for (final match in selected) match.league.id: match.league};
    final isToday = DateUtils.isSameDay(_date, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(children: [
          const Icon(Icons.sports_soccer, color: TopgolikApp.accent, size: 28),
          const SizedBox(width: 9),
          Text(t.appName, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
        ]),
        actions: [IconButton(tooltip: t.refresh, icon: const Icon(Icons.refresh_rounded), onPressed: _busy ? null : () => _loadMatches()), const SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        color: TopgolikApp.accent,
        onRefresh: () async { await _loadMatches(); await _loadLeagues(); },
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            _dateSelector(t, isToday),
            const SizedBox(height: 20),
            Row(children: [
              Text(t.matches, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const Spacer(),
              Flexible(child: _leagueSelector(t)),
            ]),
            const SizedBox(height: 12),
            if (_loading && _matches.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 64), child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _matches.isEmpty)
              _emptyState(t.connectionError, t.offlineHint, t.retry, () => _loadMatches())
            else if (selected.isEmpty)
              _emptyState(t.noMatches, _tab == 2 ? t.favoriteHint : '', t.retry, () => _loadMatches())
            else
              ...groups.entries.map((entry) => _leagueBlock(leagueById[entry.key]!, entry.value, t)),
            if (!_loading && _page < _lastPage)
              Padding(padding: const EdgeInsets.only(top: 12), child: OutlinedButton(
                onPressed: _busy ? null : () => _loadMatches(append: true),
                child: Text(t.seeAll),
              )),
            if (_error != null && _matches.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 12), child: Text(t.offlineHint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amberAccent))),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.sports_soccer_outlined), selectedIcon: const Icon(Icons.sports_soccer), label: t.all),
          NavigationDestination(icon: const Icon(Icons.sensors_outlined), selectedIcon: const Icon(Icons.sensors), label: t.live),
          NavigationDestination(icon: const Icon(Icons.star_outline_rounded), selectedIcon: const Icon(Icons.star_rounded), label: t.favorites),
        ],
      ),
    );
  }

  Widget _dateSelector(AppLocalizations t, bool today) => DecoratedBox(
        decoration: BoxDecoration(color: TopgolikApp.panel, borderRadius: BorderRadius.circular(18)),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4), child: Row(
          children: [
            IconButton(tooltip: t.yesterday, onPressed: () => _changeDate(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(child: Column(children: [
              Text(today ? t.today.toUpperCase() : MaterialLocalizations.of(context).formatMediumDate(_date).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TopgolikApp.accent, letterSpacing: 1.1)),
              const SizedBox(height: 3),
              Text(MaterialLocalizations.of(context).formatMediumDate(_date), style: const TextStyle(fontWeight: FontWeight.w600)),
            ])),
            IconButton(tooltip: t.tomorrow, onPressed: () => _changeDate(1), icon: const Icon(Icons.chevron_right)),
          ],
        )),
      );

  Widget _leagueSelector(AppLocalizations t) => DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _leagues.any((l) => l.id == _leagueId) ? _leagueId : null,
          isDense: true,
          isExpanded: true,
          dropdownColor: TopgolikApp.panel,
          icon: const Icon(Icons.keyboard_arrow_down, color: TopgolikApp.accent),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(t.allLeagues, overflow: TextOverflow.ellipsis)),
            ..._leagues.map((l) => DropdownMenuItem<int?>(value: l.id, child: Text(l.name, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (id) => setState(() => _leagueId = id),
        ),
      );

  Widget _leagueBlock(LeagueInfo league, List<FootballMatch> matches, AppLocalizations t) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(color: TopgolikApp.panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFF1D3647))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 10), child: Row(children: [
              const Icon(Icons.emoji_events_outlined, color: TopgolikApp.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(league.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
              if (league.country != null) Text(league.country!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ])),
            const Divider(height: 1, color: Color(0xFF243B49)),
            ...matches.map((match) => _matchTile(match, t)),
          ]),
        ),
      );

  Widget _matchTile(FootballMatch match, AppLocalizations t) => InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MatchDetailScreen(api: _api, matchId: match.id))),
        child: Padding(padding: const EdgeInsets.fromLTRB(12, 13, 8, 13), child: Row(children: [
          SizedBox(width: 54, child: Column(children: [
            if (match.isLive) Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFB82135), borderRadius: BorderRadius.circular(5)), child: Text(t.live.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)))
            else Text(match.isFinished ? t.finished : TimeOfDay.fromDateTime(match.startsAt).format(context), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
            if (match.isLive && (match.statusDetail?.isNotEmpty ?? false)) Padding(padding: const EdgeInsets.only(top: 5), child: Text(match.statusDetail!, style: const TextStyle(fontSize: 10, color: Colors.white60))),
          ])),
          const SizedBox(width: 9),
          Expanded(child: Column(children: [
            _teamLine(match.home, match.hasScore),
            const SizedBox(height: 11),
            _teamLine(match.away, match.hasScore),
          ])),
          IconButton(
            tooltip: t.favorites,
            icon: Icon(_favoriteIds.contains(match.id) ? Icons.star_rounded : Icons.star_border_rounded, color: _favoriteIds.contains(match.id) ? TopgolikApp.accent : Colors.white54),
            onPressed: () => _toggleFavorite(match.id),
          ),
        ])),
      );

  Widget _teamLine(TeamInfo team, bool showScore) => Row(children: [
        _teamEmblem(team),
        const SizedBox(width: 8),
        Expanded(child: Text(team.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        SizedBox(width: 25, child: Text(showScore ? '${team.score ?? ''}' : '–', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
      ]);

  Widget _teamEmblem(TeamInfo team) => SizedBox(
        height: 23, width: 23,
        child: team.logoUrl != null && Uri.tryParse(team.logoUrl!)?.scheme == 'https'
            ? Image.network(team.logoUrl!, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.shield_outlined, size: 20, color: Colors.white54))
            : const Icon(Icons.shield_outlined, size: 20, color: Colors.white54),
      );

  Widget _emptyState(String title, String subtitle, String retry, VoidCallback onRetry) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 66, horizontal: 16),
        child: Column(children: [
          const Icon(Icons.sports_soccer_outlined, size: 45, color: Colors.white38),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
          ],
          const SizedBox(height: 18), OutlinedButton(onPressed: onRetry, child: Text(retry)),
        ]),
      );
}
