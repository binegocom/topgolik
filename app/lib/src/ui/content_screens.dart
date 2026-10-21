import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'design/topgolik_ui.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tabs = [t.news, t.transfers, t.videos, t.trending];
    return Scaffold(
      appBar: AppBar(title: const TopgolikWordmark(size: 22)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < tabs.length; i++) ...[
                TopgolikPill(
                  label: tabs[i], selected: _selected == i,
                  onPressed: () => setState(() => _selected = i),
                ),
                const SizedBox(width: 8),
              ],
            ]),
          ),
          const SizedBox(height: 20),
          TopgolikPanel(
            child: EmptyFootballState(
              title: t.latestUpdates,
              details: t.newsUnavailable,
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.alerts)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TopgolikPanel(
            child: EmptyFootballState(
              title: t.alerts,
              details: t.notificationsUnavailable,
            ),
          ),
        ],
      ),
    );
  }
}

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TopgolikPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const TopgolikWordmark(),
            const SizedBox(height: 12),
            Text(t.about, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('topgolik.com', style: TextStyle(color: StadiumColors.muted)),
            const SizedBox(height: 14),
            Text(t.dataSource, style: const TextStyle(color: StadiumColors.muted)),
          ]),
        ),
      ]),
    );
  }
}
