import 'dart:io';

import 'package:explore_canada_bay/models/passport.dart';
import 'package:explore_canada_bay/models/settlement_profile.dart';
import 'package:explore_canada_bay/screens/newcomer_journey_screen.dart';
import 'package:explore_canada_bay/services/newcomer_journey_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements PassportStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('companion presents every first-month task as a tutorial page', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final passport = PassportController(store: _MemoryStore());
    final settlement = SettlementProfileController.memory();
    await passport.load();
    final repository = NewcomerJourneyRepository(
      assetLoader: (_) async =>
          File('assets/data/newcomer_journey.json').readAsStringSync(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: NewcomerJourneyScreen(
            passport: passport,
            settlement: settlement,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('One month. One clear step at a time.'), findsOneWidget);
    expect(find.text('Know how to ask for an interpreter'), findsNothing);
    for (final feature in const [
      'Home',
      'Explore map and routes',
      'Community events and groups',
      'Local services',
      'Community Passport',
      'Scan',
      'Profile and language',
    ]) {
      expect(find.text(feature), findsOneWidget);
    }

    const taskTitles = <String>[
      'Know when to call Triple Zero',
      'Know how to ask for an interpreter',
      'Find your bin collection information',
      'Plan a local public transport trip',
      'Join your local library',
      'Check your Medicare eligibility',
      'Understand your rights when renting',
      'Find free English-learning support',
      'Understand the beach flags',
      'Make pools safer for children',
      'Complete a Canada Bay route',
      'Join a community activity',
      'Help care for a local place',
    ];

    for (final title in taskTitles) {
      await tester.tap(find.byKey(const ValueKey('journey-tutorial-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Setup cards may intentionally repeat the task title beneath the page
      // heading. The current page must present the title at least once.
      expect(find.text(title), findsAtLeastNWidgets(1));
      expect(find.text('FIND IT IN'), findsOneWidget);
      expect(find.text('SAVED IN'), findsOneWidget);
      if (title == 'Know how to ask for an interpreter') {
        expect(
          find.text('Journey progress → Community Passport'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull, reason: '$title page overflowed.');
    }

    await tester.tap(find.byKey(const ValueKey('journey-tutorial-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('journey-tutorial-finish')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    passport.dispose();
    settlement.dispose();
  });
}
