import 'dart:convert';
import 'dart:io';

import 'package:explore_canada_bay/models/newcomer_journey.dart';
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

  group('newcomer journey catalogue', () {
    late NewcomerJourneyCatalog catalog;

    setUpAll(() {
      final json =
          jsonDecode(
                File('assets/data/newcomer_journey.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      catalog = NewcomerJourneyCatalog.fromJson(json);
    });

    test('includes civic, community, exploration and water safety steps', () {
      expect(catalog.tasks, isNotEmpty);
      expect(
        catalog.tasks.map((task) => task.section),
        contains('Australian water safety'),
      );
      expect(
        catalog.tasks.map((task) => task.kind).toSet(),
        containsAll(JourneyTaskKind.values),
      );
      expect(
        catalog.tasks
            .where((task) => task.section.contains('water'))
            .every((task) => task.xp == 0 && task.canSelfComplete),
        isTrue,
      );
    });

    test('uses unique task ids and official HTTPS safety links', () {
      expect(
        catalog.tasks.map((task) => task.id).toSet(),
        hasLength(catalog.tasks.length),
      );
      for (final task in catalog.tasks.where(
        (task) => task.section == 'Australian water safety',
      )) {
        final uri = Uri.parse(task.officialUrl!);
        expect(uri.scheme, 'https');
        expect(uri.hasAuthority, isTrue);
      }
    });
  });

  test('repository wraps malformed journey data', () async {
    final repository = NewcomerJourneyRepository(
      assetLoader: (_) async => '{bad json',
    );
    await expectLater(
      repository.loadCatalog(),
      throwsA(isA<JourneyRepositoryException>()),
    );
  });

  testWidgets('paged journey completes a learning step on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final passport = PassportController(store: _MemoryStore());
    await passport.load();
    final repository = NewcomerJourneyRepository(
      assetLoader: (_) async =>
          File('assets/data/newcomer_journey.json').readAsStringSync(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: NewcomerJourneyScreen(
          passport: passport,
          settlement: SettlementProfileController.memory(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'initial journey layout');

    expect(
      find.byKey(const ValueKey('journey-tutorial-intro')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('journey-tutorial-next')));
    await tester.pumpAndSettle();
    expect(find.text('Know when to call Triple Zero'), findsOneWidget);

    final complete = find.byKey(
      const ValueKey('journey-task-complete:know-triple-zero'),
    );
    await tester.ensureVisible(complete);
    await tester.pumpAndSettle();
    await tester.tap(complete);
    await tester.pumpAndSettle();

    expect(passport.hasActivity('journey:know-triple-zero'), isTrue);
    expect(passport.totalScans, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bin-night tutorial slide saves a real account essential', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final passport = PassportController(store: _MemoryStore());
    await passport.load();
    final settlement = SettlementProfileController.memory();
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

    for (var page = 0; page < 3; page++) {
      await tester.tap(find.byKey(const ValueKey('journey-tutorial-next')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Find your bin collection information'), findsOneWidget);
    final dayPicker = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(dayPicker);
    await tester.tap(dayPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tuesday').last);
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey('tutorial-save-bin-night'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(settlement.binCollectionWeekday, DateTime.tuesday);
    expect(passport.hasActivity('journey:find-bin-day'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
