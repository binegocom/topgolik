import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/api_client.dart';
import '../data/favorite_store.dart';
import '../models/football_match.dart';
import '../models/team_search.dart';
import 'content_screens.dart';
import 'design/topgolik_ui.dart';
import 'league_detail_screen.dart';
import 'match_detail_screen.dart';
import 'team_matches_screen.dart';
import 'team_search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _api = TopgolikApi();
  final _store = FavoriteStore();

  DateTime _fixtureDate = DateTime.now();
  List<FootballMatch> _homeMatches = [];
  List<FootballMatch> _fixtureMatches = [];
  List<LeagueInfo> _leagues = [];
  List<FeaturedTeam> _featured = [];
  Set<int> _favorites = {};

  Timer? _timer;
  int _tab = 0;
  int _quickTab = 0;
  int _fixtureFilter = 0;
  int? _leagueId;
  int _fixturePage = 0;
  int _fixtureLastPage = 1;
  int _homeSerial = 0;
  int _fixtureSerial = 0;
  bool _homeBusy = true;
  bool _homeError = false;
  bool _fixtureBusy = true;
  bool _fixtureError = false;
  bool _leagueBusy = true;
  bool _teamBusy = true;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreFavorites();
    _refreshHome();
    _refreshFixture();
    _refreshLeagues();
    _refreshFeatured();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!_resumed) return;
      _refreshHome(silent: true);
      if (_tab == 2) _refreshFixture(silent: true);
    });
  }

  Future<void> _restoreFavorites() async {
    try {
      final saved = await _store.load();
      if (mounted) setState(() => _favorites = saved);
    } catch (_) {
      // Local storage failures must not break live score access.
    }
  }

  Future<void> _refreshHome({bool silent = false}) async {
    final serial = ++_homeSerial;
    if (!silent) setState(() { _homeBusy = true; _homeError = false; });
    try {
      final page = await _api.matches(date: DateTime.now());
      if (!mounted || serial != _homeSerial) return;
      setState(() { _homeMatches = page.items; _homeError = false; });
    } catch (_) {
      if (mounted && serial == _homeSerial) setState(() => _homeError = true);
    } finally {
      if (mounted && serial == _homeSerial) setState(() => _homeBusy = false);
    }
  }

  Future<void> _refreshFixture({bool append = false, bool silent = false}) async {
    if (_fixtureBusy && append) return;
    final serial = ++_fixtureSerial;
    final date = _fixtureDate;
    final league = _leagueId;
    final liveOnly = _fixtureFilter == 1;
    final page = append ? _fixturePage + 1 : 1;
    if (!silent) {
      setState(() {
        _fixtureBusy = true;
        _fixtureError = false;
        if (!append) {
          _fixtureMatches = [];
          _fixturePage = 0;
        }
      });
    }
    try {
      final result = await _api.matches(
        date: date, page: page, leagueId: league, liveOnly: liveOnly,
      );
      if (!mounted || serial != _fixtureSerial) return;
      setState(() {
        _fixtureMatches = append ? [..._fixtureMatches, ...result.items] : result.items;
        _fixturePage = result.currentPage;
        _fixtureLastPage = result.lastPage;
        _fixtureError = false;
      });
    } catch (_) {
      if (mounted && serial == _fixtureSerial) setState(() => _fixtureError = true);
    } finally {
      if (mounted && serial == _fixtureSerial) setState(() => _fixtureBusy = false);
    }
  }

  Future<void> _refreshLeagues() async {
    try {
      final rows = await _api.leagues();
      if (mounted) setState(() { _leagues = rows; _leagueBusy = false; });
    } catch (_) {
      if (mounted) setState(() => _leagueBusy = false);
    }
  }

  Future<void> _refreshFeatured() async {
    try {
      final result = await _api.searchTeams();
      if (mounted) setState(() { _featured = result.featured; _teamBusy = false; });
    } catch (_) {
      if (mounted) setState(() => _teamBusy = false);
    }
  }

  Future<void> _toggleFavorite(int id) async {
    final previous = Set<int>.from(_favorites);
    final next = Set<int>.from(previous);
    if (!next.add(id)) next.remove(id);
    setState(() => _favorites = next);
    try {
      await _store.save(next);
    } catch (_) {
      if (mounted) setState(() => _favorites = previous);
    }
  }

  void _selectTab(int index) {
    if (index == _tab) return;
    setState(() => _tab = index);
    if (index == 2) _refreshFixture(silent: true);
  }

  void _selectQuick(int index) {
    setState(() => _quickTab = index);
    if (index == 3) {
      _fixtureDate = DateTime.now().add(const Duration(days: 1));
      _fixtureFilter = 0;
      _selectTab(2);
      _refreshFixture();
    } else if (index == 4) {
      _fixtureDate = DateTime.now();
      _fixtureFilter = 2;
      _selectTab(2);
      _refreshFixture();
    }
  }

  void _changeFixtureDate(int shift) {
    setState(() {
      _fixtureDate = DateTime(
        _fixtureDate.year, _fixtureDate.month, _fixtureDate.day + shift,
      );
    });
    _refreshFixture();
  }

  void _openMatch(FootballMatch match) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MatchDetailScreen(api: _api, matchId: match.id),
    ));
  }

  void _openLeague(LeagueInfo league) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LeagueDetailScreen(api: _api, league: league),
    ));
  }

  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TeamSearchScreen(api: _api),
    ));
  }

  void _openFeatured(FeaturedTeam entry) {
    final team = entry.team;
    if (team == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).teamDataUnavailable)),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TeamMatchesScreen(api: _api, team: team),
    ));
  }

  void _openContent(Widget child) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => child));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) {
      _refreshHome(silent: true);
      if (_tab == 2) _refreshFixture(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: const TopgolikWordmark(),
        actions: [
          IconButton(
            tooltip: t.searchTeams,
            onPressed: _openSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: t.alerts,
            onPressed: () => _openContent(const NotificationsScreen()),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: switch (_tab) {
        0 => _dashboard(t),
        1 => _leagueDirectory(t),
        2 => _fixtures(t),
        3 => _teamDirectory(t),
        _ => _more(t),
      },
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: t.home),
          NavigationDestination(icon: const Icon(Icons.emoji_events_outlined), selectedIcon: const Icon(Icons.emoji_events), label: t.leagues),
          NavigationDestination(icon: const Icon(Icons.calendar_month_outlined), selectedIcon: const Icon(Icons.calendar_month), label: t.matches),
          NavigationDestination(icon: const Icon(Icons.sports_jersey_outlined), selectedIcon: const Icon(Icons.sports_jersey), label: t.teams),
          NavigationDestination(icon: const Icon(Icons.menu_rounded), label: t.more),
        ],
      ),
    );
  }

  Widget _dashboard(AppLocalizations t) {
    final now = DateTime.now();
    final live = _homeMatches.where((match) => match.isLive).toList();
    final upcoming = _homeMatches.where((match) => !match.isFinished).toList();
    final highlights = upcoming.isNotEmpty ? upcoming : _homeMatches;

    return RefreshIndicator(
      color: StadiumColors.green,
      onRefresh: () async {
        await _refreshHome();
        await _refreshLeagues();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 26),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < 5; i++) ...[
                TopgolikPill(
                  label: [t.all, t.live, t.today, t.tomorrow, t.favorites][i],
                  selected: _quickTab == i,
                  onPressed: () => _selectQuick(i),
                ),
                const SizedBox(width: 7),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          if (_homeBusy && _homeMatches.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 58), child: Center(child: CircularProgressIndicator()))
          else if (highlights.isNotEmpty)
            _stadiumHero(highlights.first, t)
          else
            _stadiumPlaceholder(t),
          const SizedBox(height: 20),
          SectionHeader(
            title: t.liveMatches,
            icon: Icons.sensors,
            actionLabel: t.seeAll,
            onAction: () {
              setState(() => _fixtureFilter = 1);
              _selectTab(2);
              _refreshFixture();
            },
          ),
          const SizedBox(height: 7),
          if (_homeError && _homeMatches.isEmpty)
            EmptyFootballState(title: t.connectionError, onRetry: _refreshHome, retryLabel: t.retry)
          else if (live.isEmpty)
            TopgolikPanel(child: EmptyFootballState(title: t.noLiveMatches))
          else
            ..._grouped(live).entries.map((group) {
              final league = group.value.first.league;
              return LeagueMatchPanel(
                league: league, matches: group.value,
                favorites: _favorites, onFavorite: _toggleFavorite,
                onMatch: _openMatch, onLeague: () => _openLeague(league),
              );
            }),
          const SizedBox(height: 16),
          SectionHeader(
            title: t.homeFeatured, icon: Icons.calendar_today_outlined,
            actionLabel: t.seeAll, onAction: () => _selectTab(2),
          ),
          const SizedBox(height: 7),
          if (_homeMatches.isEmpty)
            TopgolikPanel(child: EmptyFootballState(title: t.noMatches))
          else
            ..._grouped(_homeMatches.take(8).toList()).entries.map((group) {
              final league = group.value.first.league;
              return LeagueMatchPanel(
                league: league, matches: group.value,
                favorites: _favorites, onFavorite: _toggleFavorite,
                onMatch: _openMatch, onLeague: () => _openLeague(league),
              );
            }),
          const SizedBox(height: 8),
          SectionHeader(title: t.news, icon: Icons.newspaper_rounded,
            actionLabel: t.seeAll, onAction: () => _openContent(const NewsScreen())),
          TopgolikPanel(child: Text(
            t.newsUnavailable,
            style: const TextStyle(fontSize: 13, color: StadiumColors.muted),
          )),
          const SizedBox(height: 8),
          Text(MaterialLocalizations.of(context).formatMediumDate(now),
            textAlign: TextAlign.center,
            style: const TextStyle(color: StadiumColors.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _stadiumPlaceholder(AppLocalizations t) => Container(
    height: 175,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF092C48), StadiumColors.surface, Color(0xFF06291B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: StadiumColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(Icons.stadium_outlined, color: StadiumColors.green, size: 42),
        Text(t.featuredMatch, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        Text(t.noMatches, style: const TextStyle(color: StadiumColors.muted)),
      ],
    ),
  );

  Widget _stadiumHero(FootballMatch match, AppLocalizations t) => Material(
    borderRadius: BorderRadius.circular(19),
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: () => _openMatch(match),
      child: Ink(
        height: 209,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: StadiumColors.border),
          gradient: const LinearGradient(
            colors: [Color(0xFF063D34), Color(0xFF092D4A), Color(0xFF030C13)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.stadium, color: StadiumColors.green, size: 26),
            const SizedBox(width: 7),
            Expanded(child: Text(match.league.name, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12))),
            if (match.isLive)
              const Icon(Icons.sensors, color: StadiumColors.red),
          ]),
          const Spacer(),
          Text(t.featuredMatch.toUpperCase(),
            style: const TextStyle(color: StadiumColors.green, letterSpacing: 1.4, fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 7),
          Row(children: [
            TeamCrest(url: match.home.logoUrl, size: 34),
            const SizedBox(width: 8),
            Expanded(child: Text(match.home.name, maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
            Text(match.hasScore ? '@@{match.home.score} : @@{match.away.score}' : '– : –',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(match.away.name, maxLines: 2, textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
            const SizedBox(width: 8),
            TeamCrest(url: match.away.logoUrl, size: 34),
          ]),
          const SizedBox(height: 10),
          Text(
            match.isFinished ? t.finished : match.isLive ? t.live : TimeOfDay.fromDateTime(match.startsAt).format(context),
            style: const TextStyle(color: StadiumColors.muted, fontSize: 12),
          ),
        ]),
      ),
    ),
  );

  Map<int, List<FootballMatch>> _grouped(List<FootballMatch> matches) {
    final groups = <int, List<FootballMatch>>{};
    for (final match in matches) {
      groups.putIfAbsent(match.league.id, () => []).add(match);
    }
    return groups;
  }

  Widget _leagueDirectory(AppLocalizations t) => RefreshIndicator(
    onRefresh: _refreshLeagues,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 24),
      children: [
        SectionHeader(title: t.countries, icon: Icons.emoji_events_outlined),
        const SizedBox(height: 12),
        if (_leagueBusy)
          const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
        else if (_leagues.isEmpty)
          EmptyFootballState(title: t.noLeagues, onRetry: _refreshLeagues, retryLabel: t.retry)
        else
          for (final league in _leagues)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: TopgolikPanel(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.emoji_events_outlined, color: StadiumColors.green),
                  title: Text(league.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: league.country == null ? null
                      : Text(league.country!, style: const TextStyle(color: StadiumColors.muted)),
                  trailing: const Icon(Icons.chevron_right, color: StadiumColors.muted),
                  onTap: () => _openLeague(league),
                ),
              ),
            ),
      ],
    ),
  );

  Widget _fixtures(AppLocalizations t) {
    final visible = _fixtureFilter == 2
        ? _fixtureMatches.where((match) => _favorites.contains(match.id)).toList()
        : _fixtureMatches;
    return RefreshIndicator(
      onRefresh: () => _refreshFixture(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: [
          TopgolikPanel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeFixtureDate(-1)),
              Expanded(child: Column(children: [
                Text(t.fixtures.toUpperCase(), style: const TextStyle(color: StadiumColors.green, fontWeight: FontWeight.w800, fontSize: 11)),
                Text(MaterialLocalizations.of(context).formatMediumDate(_fixtureDate),
                    textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
              ])),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeFixtureDate(1)),
            ]),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              TopgolikPill(label: t.all, selected: _fixtureFilter == 0,
                onPressed: () { setState(() => _fixtureFilter = 0); _refreshFixture(); }),
              const SizedBox(width: 8),
              TopgolikPill(label: t.live, selected: _fixtureFilter == 1,
                onPressed: () { setState(() => _fixtureFilter = 1); _refreshFixture(); }),
              const SizedBox(width: 8),
              TopgolikPill(label: t.favorites, selected: _fixtureFilter == 2,
                onPressed: () { setState(() => _fixtureFilter = 2); _refreshFixture(); }),
            ]),
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<int>(
            initialValue: _leagues.any((league) => league.id == _leagueId) ? _leagueId : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: t.chooseLeague,
              filled: true,
              fillColor: StadiumColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
              isDense: true,
            ),
            items: [
              DropdownMenuItem<int>(value: -1, child: Text(t.allLeagues)),
              for (final league in _leagues)
                DropdownMenuItem<int>(value: league.id,
                  child: Text(league.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (id) {
              setState(() => _leagueId = id == -1 ? null : id);
              _refreshFixture();
            },
          ),
          const SizedBox(height: 16),
          SectionHeader(title: t.allMatches, icon: Icons.calendar_month_outlined),
          const SizedBox(height: 8),
          if (_fixtureBusy && _fixtureMatches.isEmpty)
            const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator()))
          else if (_fixtureError && _fixtureMatches.isEmpty)
            EmptyFootballState(title: t.connectionError, onRetry: _refreshFixture, retryLabel: t.retry)
          else if (visible.isEmpty)
            EmptyFootballState(
              title: t.noMatches,
              details: _fixtureFilter == 2 ? t.favoritesToday : null,
            )
          else
            ..._grouped(visible).entries.map((entry) {
              final league = entry.value.first.league;
              return LeagueMatchPanel(
                league: league, matches: entry.value,
                favorites: _favorites, onFavorite: _toggleFavorite,
                onMatch: _openMatch, onLeague: () => _openLeague(league),
              );
            }),
          if (_fixturePage < _fixtureLastPage)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                onPressed: _fixtureBusy ? null : () => _refreshFixture(append: true),
                child: Text(t.seeAll),
              ),
            ),
        ],
      ),
    );
  }

  Widget _teamDirectory(AppLocalizations t) => RefreshIndicator(
    onRefresh: _refreshFeatured,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        TopgolikPanel(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.search, color: StadiumColors.green),
            title: Text(t.searchHint, style: const TextStyle(color: StadiumColors.muted)),
            trailing: const Icon(Icons.arrow_forward_ios, color: StadiumColors.muted, size: 15),
            onTap: _openSearch,
          ),
        ),
        const SizedBox(height: 18),
        SectionHeader(title: t.recommendedTeams, icon: Icons.star_outline),
        const SizedBox(height: 10),
        if (_teamBusy)
          const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
        else if (_featured.isEmpty)
          EmptyFootballState(title: t.connectionError, onRetry: _refreshFeatured, retryLabel: t.retry)
        else
          for (final entry in _featured)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TopgolikPanel(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: TeamCrest(url: entry.team?.logoUrl, size: 34),
                  title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing: Icon(entry.team == null ? Icons.info_outline : Icons.chevron_right,
                      color: entry.team == null ? StadiumColors.muted : StadiumColors.green),
                  onTap: () => _openFeatured(entry),
                ),
              ),
            ),
      ],
    ),
  );

  Widget _more(AppLocalizations t) {
    final options = <(IconData, String, Widget)>[
      (Icons.newspaper_rounded, t.news, const NewsScreen()),
      (Icons.notifications_none_rounded, t.alerts, const NotificationsScreen()),
      (Icons.settings_outlined, t.settings, const AppSettingsScreen()),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Center(child: TopgolikWordmark(size: 30)),
        const SizedBox(height: 22),
        for (final item in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TopgolikPanel(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(item.$1, color: StadiumColors.green),
                title: Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right, color: StadiumColors.muted),
                onTap: () => _openContent(item.$3),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(t.about, style: const TextStyle(color: StadiumColors.muted), textAlign: TextAlign.center),
        const Text('topgolik.com', style: TextStyle(color: StadiumColors.green), textAlign: TextAlign.center),
      ],
    );
  }
}
