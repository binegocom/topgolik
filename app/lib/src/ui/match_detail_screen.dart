import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/api_client.dart';
import '../models/football_match.dart';
import '../models/match_center.dart';
import 'design/topgolik_ui.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({super.key, required this.api, required this.matchId});
  final TopgolikApi api;
  final int matchId;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  late Future<FootballMatch> _future;
  Future<MatchCenterData>? _centerFuture;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.api.match(widget.matchId);
    _centerFuture = _tab == 0 ? null : widget.api.matchCenter(widget.matchId);
  }

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      if (index > 0) {
        _centerFuture ??= widget.api.matchCenter(widget.matchId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.matchCenter),
        actions: [
          IconButton(
            tooltip: t.refresh,
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<FootballMatch>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return EmptyFootballState(
              title: t.connectionError,
              onRetry: () => setState(_load),
              retryLabel: t.retry,
            );
          }
          final match = snapshot.data!;
          final tabs = [t.overview, t.statistics, t.lineups, t.commentary];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF31588B)),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF19395D), Color(0xFF101F36), Color(0xFF0B182B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(children: [
                  Text(match.league.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: StadiumColors.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(
                    MaterialLocalizations.of(context).formatMediumDate(match.startsAt),
                    style: const TextStyle(color: StadiumColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 22),
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: Column(children: [
                      TeamCrest(url: match.home.logoUrl, size: 54),
                      const SizedBox(height: 9),
                      Text(match.home.name, maxLines: 2, textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ])),
                    Column(children: [
                      Text(
                        match.hasScore
                            ? '${match.home.score} : ${match.away.score}'
                            : '– : –',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 32, letterSpacing: -1),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        match.isLive ? t.live : match.isFinished ? t.finished : t.scheduled,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                          color: match.isLive ? StadiumColors.red : StadiumColors.blue),
                      ),
                      if (match.statusDetail?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(match.statusDetail!, style: const TextStyle(color: StadiumColors.muted, fontSize: 11)),
                      ],
                    ]),
                    Expanded(child: Column(children: [
                      TeamCrest(url: match.away.logoUrl, size: 54),
                      const SizedBox(height: 9),
                      Text(match.away.name, maxLines: 2, textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ])),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (var i = 0; i < tabs.length; i++) ...[
                    TopgolikPill(label: tabs[i], selected: _tab == i,
                      onPressed: () => _selectTab(i)),
                    const SizedBox(width: 7),
                  ],
                ]),
              ),
              const SizedBox(height: 15),
              if (_tab == 0)
                TopgolikPanel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _line(t.kickoff, TimeOfDay.fromDateTime(match.startsAt).format(context)),
                    const Divider(height: 24, color: StadiumColors.border),
                    _line(t.updated, MaterialLocalizations.of(context).formatMediumDate(match.updatedAt)),
                    const Divider(height: 24, color: StadiumColors.border),
                    _line(t.dataSource, match.source),
                    if (match.statusDetail?.isNotEmpty == true) ...[
                      const Divider(height: 24, color: StadiumColors.border),
                      _line(t.events, match.statusDetail!),
                    ],
                  ]),
                )
              else
                _detailsSection(match, t.noDetails, t.connectionError, t.retry),
            ],
          );
        },
      ),
    );
  }

  Widget _line(String label, String value) => Row(children: [
    Expanded(child: Text(label, style: const TextStyle(color: StadiumColors.muted))),
    Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
  ]);

  Widget _detailsSection(
    FootballMatch match, String noData, String errorText, String retryLabel,
  ) {
    final t = AppLocalizations.of(context);
    return FutureBuilder<MatchCenterData>(
      future: _centerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return EmptyFootballState(
            title: errorText,
            details: noData,
            retryLabel: retryLabel,
            onRetry: () => setState(() =>
              _centerFuture = widget.api.matchCenter(widget.matchId)),
          );
        }
        final data = snapshot.data!;
        if (!data.supported) {
          return TopgolikPanel(child: EmptyFootballState(title: noData));
        }

        if (_tab == 1) {
          if (data.homeStats.isEmpty && data.awayStats.isEmpty) {
            return TopgolikPanel(child: EmptyFootballState(title: noData));
          }
          return Column(children: [
            _detailList(match.home.name,
              data.homeStats.map((stat) => _labelValue(stat.label, stat.value)).toList()),
            const SizedBox(height: 10),
            _detailList(match.away.name,
              data.awayStats.map((stat) => _labelValue(stat.label, stat.value)).toList()),
          ]);
        }

        if (_tab == 2) {
          if (data.homePlayers.isEmpty && data.awayPlayers.isEmpty) {
            return TopgolikPanel(child: EmptyFootballState(title: noData));
          }
          return Column(children: [
            _detailList(match.home.name, data.homePlayers.map(_playerRow).toList()),
            const SizedBox(height: 10),
            _detailList(match.away.name, data.awayPlayers.map(_playerRow).toList()),
          ]);
        }

        if (data.events.isEmpty) {
          return TopgolikPanel(child: EmptyFootballState(title: noData));
        }
        return _detailList(t.events, data.events.map((event) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 48,
              child: Text(event.minute ?? '–',
                style: const TextStyle(color: StadiumColors.green, fontWeight: FontWeight.w800)),
            ),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (event.description != null && event.description != event.title) ...[
                  const SizedBox(height: 3),
                  Text(event.description!,
                    style: const TextStyle(color: StadiumColors.muted, fontSize: 12)),
                ],
              ],
            )),
          ]),
        )).toList());
      },
    );
  }

  Widget _detailList(String title, List<Widget> entries) =>
      TopgolikPanel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const Divider(color: StadiumColors.border, height: 20),
          ...entries,
        ],
      ));

  Widget _playerRow(MatchCenterPlayer player) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      const Icon(Icons.person_outline, size: 19, color: StadiumColors.green),
      const SizedBox(width: 9),
      Expanded(child: Text(player.name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600))),
      if (player.position != null)
        Text(player.position!, style: const TextStyle(color: StadiumColors.muted)),
    ]),
  );

  Widget _labelValue(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: StadiumColors.muted))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
    ]),
  );

}
