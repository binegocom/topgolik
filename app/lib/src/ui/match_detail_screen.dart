import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../data/api_client.dart';
import '../models/football_match.dart';
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
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = widget.api.match(widget.matchId);

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
              TopgolikPanel(
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
                      TeamCrest(url: match.home.logoUrl, size: 48),
                      const SizedBox(height: 9),
                      Text(match.home.name, maxLines: 2, textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ])),
                    Column(children: [
                      Text(
                        match.hasScore
                            ? '${match.home.score} : ${match.away.score}'
                            : '– : –',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 30),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        match.isLive ? t.live : match.isFinished ? t.finished : t.scheduled,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                          color: match.isLive ? StadiumColors.red : StadiumColors.green),
                      ),
                      if (match.statusDetail?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(match.statusDetail!, style: const TextStyle(color: StadiumColors.muted, fontSize: 11)),
                      ],
                    ]),
                    Expanded(child: Column(children: [
                      TeamCrest(url: match.away.logoUrl, size: 48),
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
                      onPressed: () => setState(() => _tab = i)),
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
                TopgolikPanel(
                  child: EmptyFootballState(title: tabs[_tab], details: t.noDetails),
                ),
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
}
