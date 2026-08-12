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

  testWidgets(
    'companion presents one current activity and a connected roadmap',
    (tester) async {
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

      const taskIds = <String>[
        'know-triple-zero',
        'use-an-interpreter',
        'find-bin-day',
        'plan-first-trip',
        'discover-library',
        'check-medicare',
        'know-rental-rights',
        'find-english-support',
        'swim-between-flags',
        'home-pool-safety',
        'complete-local-route',
        'join-community-activity',
        'help-local-environment',
      ];

      expect(
        find.byKey(const ValueKey('journey-today:know-triple-zero')),
        findsOneWidget,
      );
      for (final taskId in taskIds) {
        expect(find.byKey(ValueKey('journey-roadmap:$taskId')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      passport.dispose();
      settlement.dispose();
    },
  );
}
