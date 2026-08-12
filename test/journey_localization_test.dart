import 'dart:convert';
import 'dart:io';

import 'package:explore_canada_bay/l10n/app_localizations.dart';
import 'package:explore_canada_bay/l10n/journey_activity_localizations.dart';
import 'package:explore_canada_bay/l10n/journey_localizations.dart';
import 'package:explore_canada_bay/models/newcomer_journey.dart';
import 'package:explore_canada_bay/models/passport.dart';
import 'package:explore_canada_bay/models/settlement_profile.dart';
import 'package:explore_canada_bay/screens/newcomer_journey_screen.dart';
import 'package:explore_canada_bay/services/newcomer_journey_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  test('every onboarding language fully translates the newcomer journey', () {
    final catalog = NewcomerJourneyCatalog.fromJson(
      jsonDecode(File('assets/data/newcomer_journey.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final english = JourneyLocalizations.forLocale(const Locale('en'));
    final sections = catalog.tasks.map((task) => task.section).toSet();
    final contextTasks = catalog.tasks.where(
      (task) => english.contextNote(task.id) != null,
    );

    for (final locale in AppLocalizations.supportedLocales.skip(1)) {
      final translated = JourneyLocalizations.forLocale(locale);
      final code = locale.languageCode;

      for (final key in JourneyLocalizations.requiredUiKeys) {
        expect(
          translated.ui(key),
          isNot(english.ui(key)),
          reason: '$code must translate journey UI key "$key".',
        );
      }
      expect(translated.progress(2, 13), isNot(english.progress(2, 13)));
      expect(translated.progress(2, 13), allOf(contains('2'), contains('13')));

      for (final section in sections) {
        expect(
          translated.section(section),
          isNot(english.section(section)),
          reason: '$code must translate section "$section".',
        );
      }
      for (final task in catalog.tasks) {
        expect(
          translated.title(task),
          isNot(english.title(task)),
          reason: '$code must translate ${task.id}.title.',
        );
        expect(
          translated.summary(task),
          isNot(english.summary(task)),
          reason: '$code must translate ${task.id}.summary.',
        );
        expect(
          translated.action(task),
          isNot(english.action(task)),
          reason: '$code must translate ${task.id}.action.',
        );
      }
      for (final task in contextTasks) {
        expect(
          translated.contextNote(task.id),
          isNot(english.contextNote(task.id)),
          reason: '$code must translate ${task.id} cultural context.',
        );
      }
      for (final verification in JourneyVerification.values) {
        final task = catalog.tasks.firstWhere(
          (task) => task.verification == verification,
        );
        expect(
          translated.verification(task),
          isNot(english.verification(task)),
          reason: '$code must translate ${verification.name} verification.',
        );
      }
    }
  });

  test('stored Journey stories follow the current locale', () {
    final catalog = NewcomerJourneyCatalog.fromJson(
      jsonDecode(File('assets/data/newcomer_journey.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final storedCopy = JourneyLocalizations.forLocale(const Locale('zh'));

    for (final task in catalog.tasks) {
      final record = PassportScanRecord(
        rewardId: task.activityId,
        placeName: storedCopy.title(task),
        xpAwarded: task.xp,
        scannedAt: DateTime.utc(2026, 8, 10),
        badgeId: task.badgeId,
        source: 'activity',
        content: PassportQrContent(
          title: storedCopy.title(task),
          body: storedCopy.summary(task),
          category: storedCopy.section(task.section),
          officialUrl: task.officialUrl,
          localizationId: 'journey.task:${task.id}',
        ),
      );

      for (final locale in AppLocalizations.supportedLocales) {
        final journeyCopy = JourneyLocalizations.forLocale(locale);
        final localized = JourneyActivityLocalizations.forLocale(
          locale,
        ).resolve(record);

        expect(localized.placeName, journeyCopy.title(task));
        expect(localized.content?.title, journeyCopy.title(task));
        expect(localized.content?.body, journeyCopy.summary(task));
        expect(localized.content?.category, journeyCopy.section(task.section));
        expect(localized.content?.officialUrl, task.officialUrl);
      }
    }
  });

  test('legacy practical Journey stories use saved stable details', () async {
    final settlement = SettlementProfileController.memory();
    await settlement.saveTransportShortcut(stop: 'Rhodes', mode: 'Train');
    final record = PassportScanRecord(
      rewardId: 'journey:plan-first-trip',
      placeName: 'Usual transport stop saved',
      xpAwarded: 0,
      scannedAt: DateTime.utc(2026, 8, 10),
      source: 'activity',
      content: const PassportQrContent(
        title: 'Usual transport stop saved',
        body: 'Rhodes is saved as your Train starting point.',
        category: 'Local essentials',
      ),
    );
    final locale = const Locale('it');
    final copy = JourneyLocalizations.forLocale(locale);
    final localized = JourneyActivityLocalizations.forLocale(
      locale,
    ).resolve(record, settlement: settlement);

    expect(localized.placeName, copy.ui('transportActivityTitle'));
    expect(
      localized.content?.body,
      copy.message('transportActivityBody', {
        'stop': 'Rhodes',
        'mode': copy.transportMode('Train'),
      }),
    );
    expect(localized.content?.category, copy.ui('localEssentials'));
  });

  test('Council and developer defaults are localized in every language', () {
    final english = JourneyLocalizations.forLocale(const Locale('en'));

    for (final locale in AppLocalizations.supportedLocales.skip(1)) {
      final copy = JourneyLocalizations.forLocale(locale);
      expect(copy.ui('councilIssue'), isNot(english.ui('councilIssue')));
      expect(copy.ui('developerTools'), isNot(english.ui('developerTools')));
    }
  });

  testWidgets('journey renders every onboarding language on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    const languageCodes = <String>['zh', 'ko', 'it', 'hi'];

    for (final languageCode in languageCodes) {
      final passport = PassportController(store: _MemoryStore());
      await passport.load();
      final repository = NewcomerJourneyRepository(
        assetLoader: (_) async =>
            File('assets/data/newcomer_journey.json').readAsStringSync(),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(languageCode),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: NewcomerJourneyScreen(
            passport: passport,
            settlement: SettlementProfileController.memory(),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          JourneyLocalizations.forLocale(
            Locale(languageCode),
          ).ui('journeyTitle'),
        ),
        findsOneWidget,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '$languageCode journey should render without overflow.',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
