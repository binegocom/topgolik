import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/api_client.dart';
import '../models/team_search.dart';
import 'team_matches_screen.dart';
import 'design/topgolik_ui.dart';


class TeamSearchScreen extends StatefulWidget {
  const TeamSearchScreen({super.key, required this.api});
  final TopgolikApi api;

  @override
  State<TeamSearchScreen> createState() => _TeamSearchScreenState();
}

class _TeamSearchScreenState extends State<TeamSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;
  bool _loading = true;
  bool _error = false;
  TeamSearchResponse? _response;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _load('');
  }

  void _onChange() {
    _debounce?.cancel();
    ++_requestId; // Invalidate an in-flight query before the debounce fires.
    setState(() {
      _loading = true;
      _error = false;
      _response = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(_controller.text),
    );
  }

  Future<void> _load(String query) async {
    final requestId = ++_requestId;
    try {
      final data = await widget.api.searchTeams(query: query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = false;
        _response = data;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _onTeamSelected(SearchTeam? team) {
    if (team == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).teamDataUnavailable)),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TeamMatchesScreen(api: widget.api, team: team),
    ));
  }

  @override
  void dispose() {
    _requestId++;
    _debounce?.cancel();
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final featured = _controller.text.trim().isEmpty;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 80,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: t.searchHint,
            counterText: '',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: StadiumColors.green),
            suffixIcon: featured
                ? null
                : IconButton(
                    tooltip: t.clearSearch,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _controller.clear,
                  ),
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.connectionError, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            setState(() => _loading = true);
                            _load(_controller.text);
                          },
                          child: Text(t.retry),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Text(
                        featured ? t.recommendedTeams : t.searchResults,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 14),
                      if (featured)
                        for (final entry in _response?.featured ?? <FeaturedTeam>[])
                          _teamTile(entry.name, entry.team)
                      else if (_response?.results.isEmpty ?? true)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Text(t.noTeamResults, textAlign: TextAlign.center),
                        )
                      else
                        for (final entry in _response?.results ?? <SearchTeam>[])
                          _teamTile(entry.name, entry),
                    ],
                  ),
      ),
    );
  }

  Widget _teamTile(String label, SearchTeam? team) {
    final logo = team?.logoUrl;
    final hasLogo = logo != null && Uri.tryParse(logo)?.scheme == 'https';
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: StadiumColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          onTap: () => _onTeamSelected(team),
          leading: TeamCrest(url: hasLogo ? logo : null, size: 38),
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          trailing: Icon(
            team != null ? Icons.chevron_right_rounded : Icons.info_outline,
            color: team != null ? TopgolikApp.accent : Colors.white38,
          ),
        ),
      ),
    );
  }
}
