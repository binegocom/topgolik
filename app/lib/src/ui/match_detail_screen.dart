import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../data/api_client.dart';
import '../models/football_match.dart';
import 'topgolik_app.dart';

class MatchDetailScreen extends StatefulWidget {
  const MatchDetailScreen({super.key, required this.api, required this.matchId});
  final TopgolikApi api;
  final int matchId;

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  late Future<FootballMatch> _future;

  @override
  void initState() { super.initState(); _load(); }
  void _load() { _future = widget.api.match(widget.matchId); }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.matchDetails), actions: [IconButton(tooltip: t.refresh, onPressed: () => setState(_load), icon: const Icon(Icons.refresh))]),
      body: FutureBuilder<FootballMatch>(future: _future, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t.connectionError, textAlign: TextAlign.center)));
        }
        final match = snapshot.data!;
        final score = match.hasScore ? '${match.home.score} : ${match.away.score}' : '– : –';
        return ListView(padding: const EdgeInsets.all(20), children: [
          Center(child: Text(match.league.name, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
          const SizedBox(height: 24),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _team(match.home.name)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Column(children: [
              Text(score, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(match.isLive ? t.live : match.isFinished ? t.finished : t.scheduled,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: match.isLive ? TopgolikApp.accent : Colors.white60)),
            ])),
            Expanded(child: _team(match.away.name)),
          ]),
          const SizedBox(height: 28),
          const Divider(),
          _metadata(t.kickoff, MaterialLocalizations.of(context).formatFullDate(match.startsAt)),
          _metadata(t.updated, MaterialLocalizations.of(context).formatMediumDate(match.updatedAt)),
          _metadata(t.dataSource, match.source),
          if (match.statusDetail?.isNotEmpty ?? false) _metadata(t.matches, match.statusDetail!),
        ]);
      }),
    );
  }

  Widget _team(String name) => Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700));
  Widget _metadata(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: Row(children: [
    Expanded(child: Text(label, style: const TextStyle(color: Colors.white60))),
    Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
  ]));
}
