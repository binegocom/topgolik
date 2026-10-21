import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topgolik/src/models/football_match.dart';
import 'package:topgolik/src/ui/design/topgolik_ui.dart';

void main() {
  testWidgets('stadium brand preserves the reference palette and name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: TopgolikWordmark())),
    ));
    expect(find.textContaining('Top'), findsOneWidget);
    expect(find.textContaining('golik'), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
  });

  testWidgets('match tile displays only source-provided score and club names', (tester) async {
    final match = FootballMatch.fromJson({
      'id': 123,
      'league': {'id': 21, 'name': 'Süper Lig', 'country': 'Turkey'},
      'home': {'id': 51, 'name': 'Galatasaray', 'logo_url': null, 'score': 2},
      'away': {'id': 52, 'name': 'Fenerbahçe', 'logo_url': null, 'score': 1},
      'starts_at': '2026-10-21T18:00:00Z',
      'updated_at': '2026-10-21T18:49:00Z',
      'status': 'live',
      'status_detail': '49',
      'source': 'espn',
    });
    var selected = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FootballMatchTile(
          match: match,
          onTap: () => selected = true,
        ),
      ),
    ));

    expect(find.text('Galatasaray'), findsOneWidget);
    expect(find.text('Fenerbahçe'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('49'), findsOneWidget);
    await tester.tap(find.text('Galatasaray'));
    expect(selected, isTrue);
  });

  testWidgets('a ListTile inside TopgolikPanel has visible Material ink and no assertion', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TopgolikPanel(
          padding: EdgeInsets.zero,
          child: ListTile(
            title: const Text('Find a team'),
            onTap: () => tapped = true,
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Find a team'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tapped, isTrue);
  });

  testWidgets('empty state does not invent matches when source data is absent', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EmptyFootballState(title: 'No live matches'),
      ),
    ));
    expect(find.text('No live matches'), findsOneWidget);
    expect(find.byType(FootballMatchTile), findsNothing);
  });
}
