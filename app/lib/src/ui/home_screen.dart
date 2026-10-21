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
import 'premier_league_players_screen.dart';

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
  }

  void _selectQuick(int index) {
    setState(() => _quickTab = index);
    if (index == 0) return;
    _fixtureDate = index == 3
        ? DateTime.now().add(const Duration(days: 1))
        : DateTime.now();
    _fixtureFilter = index == 1 ? 1 : index == 4 ? 2 : 0;
    _selectTab(2);
    _refreshFixture();
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
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: StadiumColors.border)),
        ),
        child: NavigationBar(
        height: 70,
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: t.home),
          NavigationDestination(icon: const Icon(Icons.emoji_events_outlined), selectedIcon: const Icon(Icons.emoji_events), label: t.leagues),
          NavigationDestination(icon: const Icon(Icons.calendar_month_outlined), selectedIcon: const Icon(Icons.calendar_month), label: t.matches),
          NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups), label: t.teams),
          NavigationDestination(icon: const Icon(Icons.menu_rounded), label: t.more),
        ],
        ),
      ),
    );
  }

  Widget _dashboard(AppLocalizations t) {
    final now = DateTime.now();
    final live = _homeMatches.where((match) => match.isLive).toList();
    final upcoming = _homeMatches.where((match) => !match.isFinished).toList();
    final highlights = upcoming.isNotEmpty ? upcoming : _homeMatches;

    return RefreshIndicator(
      color: StadiumColors.blue,
      onRefresh: () async {
        await _refreshHome();
        await _refreshLeagues();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.today.toUpperCase(),
                    style: const TextStyle(
                      color: StadiumColors.blue, fontSize: 11,
                      fontWeight: FontWeight.w900, letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    MaterialLocalizations.of(context).formatMediumDate(now),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              )),
              Material(
                color: StadiumColors.raised,
                borderRadius: BorderRadius.circular(12),
                child: IconButton(
                  tooltip: t.fixtures,
                  onPressed: () => _selectTab(2),
                  icon: const Icon(Icons.calendar_month_outlined, color: StadiumColors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 15),
          if (_homeBusy && _homeMatches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 44),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_homeError && _homeMatches.isEmpty)
            EmptyFootballState(
              title: t.connectionError, onRetry: _refreshHome, retryLabel: t.retry,
            )
          else if (highlights.isNotEmpty)
            _stadiumHero(highlights.first, t)
          else
            _stadiumPlaceholder(t),
          const SizedBox(height: 19),
          SectionHeader(
            title: t.liveMatches,
            icon: Icons.sensors_rounded,
            actionLabel: t.seeAll,
            onAction: () {
              setState(() => _fixtureFilter = 1);
              _selectTab(2);
              _refreshFixture();
            },
          ),
          const SizedBox(height: 9),
          if (live.isEmpty)
            TopgolikPanel(
              child: EmptyFootballState(title: t.noLiveMatches),
            )
          else
            ..._grouped(live).entries.map((group) {
              final league = group.value.first.league;
              return LeagueMatchPanel(
                league: league, matches: group.value,
                favorites: _favorites, onFavorite: _toggleFavorite,
                onMatch: _openMatch, onLeague: () => _openLeague(league),
              );
            }),
          const SizedBox(height: 12),
          SectionHeader(
            title: t.allMatches,
            icon: Icons.calendar_today_outlined,
            actionLabel: t.seeAll,
            onAction: () => _selectTab(2),
          ),
          const SizedBox(height: 9),
          if (_homeMatches.isEmpty)
            TopgolikPanel(child: EmptyFootballState(title: t.noMatches))
          else
            ..._grouped(_homeMatches.take(12).toList()).entries.map((group) {
              final league = group.value.first.league;
              return LeagueMatchPanel(
                league: league, matches: group.value,
                favorites: _favorites, onFavorite: _toggleFavorite,
                onMatch: _openMatch, onLeague: () => _openLeague(league),
              );
            }),
        ],
      ),
    );
  }

  Widget _stadiumPlaceholder(AppLocalizations t) => TopgolikPanel(
    child: SizedBox(
      height: 115,
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: StadiumColors.raised,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.sports_soccer, color: StadiumColors.blue, size: 27),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.featuredMatch, style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 16,
                )),
                const SizedBox(height: 4),
                Text(t.noMatches, style: const TextStyle(
                  color: StadiumColors.muted, fontSize: 12,
                )),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _stadiumHero(FootballMatch match, AppLocalizations t) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openMatch(match),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF31588B)),
          gradient: const LinearGradient(
            colors: [Color(0xFF19395D), Color(0xFF101F36), Color(0xFF0B182B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined, size: 16, color: StadiumColors.blue),
                const SizedBox(width: 7),
                Expanded(child: Text(
                  match.league.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12,
                  ),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: match.isLive
                        ? const Color(0x33FF6479) : const Color(0x304F8DF3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    match.isLive ? t.live
                        : match.isFinished ? t.finished : t.scheduled,
                    style: TextStyle(
                      color: match.isLive ? StadiumColors.red : StadiumColors.blue,
                      fontSize: 10, fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _featuredTeam(match.home)),
                SizedBox(
                  width: 84,
                  child: Column(children: [
                    Text(
                      match.hasScore
                          ? '${match.home.score} : ${match.away.score}' : '– : –',
                      style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TimeOfDay.fromDateTime(match.startsAt).format(context),
                      style: const TextStyle(
                        fontSize: 11, color: StadiumColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                ),
                Expanded(child: _featuredTeam(match.away)),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _featuredTeam(TeamInfo team) => Column(
    children: [
      TeamCrest(url: team.logoUrl, size: 41),
      const SizedBox(height: 7),
      Text(
        team.name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    ],
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

  Widget _fixtureDateStrip(AppLocalizations t) {
    final today = DateTime.now();
    final material = MaterialLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var offset = -2; offset <= 2; offset++) ...[
            Builder(builder: (context) {
              final day = DateTime(
                _fixtureDate.year, _fixtureDate.month, _fixtureDate.day + offset,
              );
              final label = DateUtils.isSameDay(day, today)
                  ? t.today
                  : DateUtils.isSameDay(day, today.subtract(const Duration(days: 1)))
                      ? t.yesterday
                      : DateUtils.isSameDay(day, today.add(const Duration(days: 1)))
                          ? t.tomorrow
                          : material.formatShortDate(day);
              return TopgolikPill(
                label: label,
                selected: offset == 0,
                onPressed: () {
                  if (offset != 0) _changeFixtureDate(offset);
                },
              );
            }),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

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
          _fixtureDateStrip(t),
          const SizedBox(height: 12),
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
      (Icons.person_search_outlined, t.playerStats, PremierLeaguePlayersScreen(api: _api)),
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
