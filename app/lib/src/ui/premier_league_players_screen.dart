import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/api_client.dart';
import '../models/premier_league_player.dart';
import 'design/topgolik_ui.dart';

class PremierLeaguePlayersScreen extends StatefulWidget {
  const PremierLeaguePlayersScreen({super.key, required this.api});
  final TopgolikApi api;

  @override
  State<PremierLeaguePlayersScreen> createState() => _PremierLeaguePlayersScreenState();
}

class _PremierLeaguePlayersScreenState extends State<PremierLeaguePlayersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;
  bool _loading = true;
  bool _error = false;
  List<PremierLeaguePlayer> _players = [];

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
    _load('');
  }

  void _onSearch() {
    _debounce?.cancel();
    ++_requestId;
    setState(() {
      _loading = true;
      _error = false;
    });
    _debounce = Timer(const Duration(milliseconds: 350),
      () => _load(_search.text.trim()));
  }

  Future<void> _load(String term) async {
    final serial = ++_requestId;
    try {
      final response = await widget.api.premierLeaguePlayers(query: term);
      if (!mounted || serial != _requestId) return;
      setState(() {
        _players = response.players;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted || serial != _requestId) return;
      setState(() {
        _players = [];
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    ++_requestId;
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.playerStats)),
      body: RefreshIndicator(
        onRefresh: () => _load(_search.text.trim()),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            TopgolikPanel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.premierLeagueOnly,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 8),
                Text(t.playerStatsNote,
                  style: const TextStyle(color: StadiumColors.muted, fontSize: 12)),
              ],
            )),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              maxLength: 80,
              decoration: InputDecoration(
                hintText: t.playerSearchHint,
                counterText: '',
                prefixIcon: const Icon(Icons.search_rounded, color: StadiumColors.green),
                suffixIcon: _search.text.isEmpty ? null : IconButton(
                  tooltip: t.clearSearch,
                  onPressed: _search.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(36), child: CircularProgressIndicator()))
            else if (_error)
              EmptyFootballState(
                title: t.connectionError,
                details: t.playerStatsUnavailable,
                onRetry: () => _load(_search.text.trim()),
                retryLabel: t.retry,
              )
            else if (_players.isEmpty)
              EmptyFootballState(title: t.playerStatsUnavailable)
            else
              for (final player in _players)
                _playerCard(t, player),
          ],
        ),
      ),
    );
  }

  Widget _playerCard(AppLocalizations t, PremierLeaguePlayer player) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TopgolikPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.person_outline_rounded, size: 30, color: StadiumColors.green),
              const SizedBox(width: 9),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(player.club,
                    style: const TextStyle(color: StadiumColors.muted, fontSize: 12)),
                ],
              )),
            ]),
            const Divider(color: StadiumColors.border, height: 22),
            Row(children: [
              _metric(t.playerGoals, player.goals?.toString()),
              _metric(t.playerAssists, player.assists?.toString()),
              _metric(t.playerMinutes, player.minutes?.toString()),
              _metric(t.playerExpectedGoals, player.expectedGoals),
            ]),
          ]),
        ),
      );

  Widget _metric(String label, String? value) => Expanded(
    child: Column(children: [
      Text(value ?? '–', style: const TextStyle(
        fontWeight: FontWeight.w900, fontSize: 15, color: StadiumColors.green)),
      const SizedBox(height: 5),
      Text(label, textAlign: TextAlign.center,
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, color: StadiumColors.muted)),
    ]),
  );
}
