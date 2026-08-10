import 'dart:convert';
import 'dart:io';

import 'package:explore_canada_bay/models/newcomer_journey.dart';
import 'package:explore_canada_bay/models/passport.dart';
import 'package:explore_canada_bay/models/settlement_profile.dart';
import 'package:explore_canada_bay/screens/newcomer_journey_screen.dart';
import 'package:explore_canada_bay/services/newcomer_journey_repository.dart';
import 'package:explore_canada_bay/services/journey_calendar_service.dart';
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

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder.');
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

  test(
    'calendar support creates an all-day goal on the correct journey day',
    () {
      final task = NewcomerJourneyTask(
        id: 'test-goal',
        title: 'Meet the community',
        summary: 'Try one welcoming local activity.',
        section: 'Feel connected',
        kind: JourneyTaskKind.community,
        verification: JourneyVerification.self,
        actionLabel: 'Open',
        badgeId: 'community_participant',
        xp: 0,
        sortOrder: 1,
      );

      final uri = const JourneyCalendarService().eventUri(
        task: task,
        journeyStart: DateTime(2026, 8, 10),
        day: 5,
      );

      expect(uri.host, 'calendar.google.com');
      expect(uri.queryParameters['dates'], '20260814/20260815');
      expect(uri.queryParameters['text'], contains('Meet the community'));
    },
  );

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

    final quickMessage = find.byKey(const ValueKey('journey-quick-message'));
    await _pumpUntilFound(tester, quickMessage);

    expect(find.byType(SnackBar), findsNothing);
    expect(tester.getTopLeft(quickMessage).dy, lessThan(80));
    expect(
      find.byKey(const ValueKey('journey-tutorial-next')).hitTestable(),
      findsOneWidget,
    );

    expect(settlement.binCollectionWeekday, DateTime.tuesday);
    expect(passport.hasActivity('journey:find-bin-day'), isTrue);

    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 200));
    expect(quickMessage, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('call it a day saves tomorrow and returns home', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final passport = PassportController(store: _MemoryStore());
    await passport.load();
    final settlement = SettlementProfileController.memory();
    var openedHome = false;
    final repository = NewcomerJourneyRepository(
      assetLoader: (_) async =>
          File('assets/data/newcomer_journey.json').readAsStringSync(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: NewcomerJourneyScreen(
            passport: passport,
            settlement: settlement,
            repository: repository,
            onOpenHome: () => openedHome = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journey-tutorial-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('journey-call-it-a-day')));
    await tester.pumpAndSettle();

    expect(settlement.journeyResumePage, 2);
    expect(openedHome, isTrue);
  });
}
