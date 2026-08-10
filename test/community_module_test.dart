import 'dart:convert';
import 'dart:io';

import 'package:explore_canada_bay/l10n/app_localizations.dart';
import 'package:explore_canada_bay/l10n/community_services_localizations.dart';
import 'package:explore_canada_bay/models/community_item.dart';
import 'package:explore_canada_bay/screens/community_screen.dart';
import 'package:explore_canada_bay/services/community_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object> _validItem({
  String id = 'welcome',
  String category = 'events',
  String officialUrl = 'https://www.canadabay.nsw.gov.au/whats-on',
}) {
  return {
    'id': id,
    'title': 'Community welcome',
    'category': category,
    'summary': 'Meet people nearby.',
    'details': 'A welcoming local activity.',
    'location': 'Canada Bay',
    'schedule': 'Weekly',
    'cost': 'Free',
    'audience': 'Everyone',
    'sourceLabel': 'City of Canada Bay Council',
    'officialUrl': officialUrl,
    'actionLabel': 'Check details',
    'featured': true,
    'verifiedOn': '2026-07-24',
    'tags': ['welcome', 'community'],
    'sortOrder': 1,
  };
}

class _FakeCommunityRepository extends CommunityRepository {
  _FakeCommunityRepository(this.items);

  final List<CommunityItem> items;

  @override
  Future<List<CommunityItem>> load() async => items;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Community catalogue', () {
    test('loads every Product Brief category from bundled JSON', () async {
      final items = await const CommunityRepository().load();

      expect(items, hasLength(18));
      expect(items.map((item) => item.id).toSet(), hasLength(items.length));
      expect(
        items.map((item) => item.category).toSet(),
        containsAll(CommunityCategory.values),
      );
      expect(items.every((item) => item.officialUri.isAbsolute), isTrue);
      expect(items.every((item) => item.sourceLabel.isNotEmpty), isTrue);
    });

    test(
      'bundled items contain complete content for every app language',
      () async {
        final items = await const CommunityRepository().load();

        for (final item in items) {
          expect(
            item.translations.keys.toSet(),
            containsAll(CommunityItem.requiredTranslationLanguageCodes),
            reason: '${item.id} must contain every supported translation.',
          );
          for (final languageCode
              in CommunityItem.requiredTranslationLanguageCodes) {
            final translation = item.translations[languageCode];
            expect(
              translation,
              isNotNull,
              reason: '${item.id}.$languageCode is missing.',
            );
            final scalarFields = <String>[
              translation!.title,
              translation.summary,
              translation.details,
              translation.location,
              translation.schedule,
              translation.cost,
              translation.audience,
              translation.actionLabel,
            ];
            expect(
              scalarFields.every((value) => value.trim().isNotEmpty),
              isTrue,
              reason: '${item.id}.$languageCode has empty display text.',
            );
            expect(
              scalarFields.any((value) => value.contains('\uFFFD')),
              isFalse,
              reason: '${item.id}.$languageCode contains invalid Unicode.',
            );
            expect(
              translation.tags.every((tag) => tag.trim().isNotEmpty),
              isTrue,
              reason: '${item.id}.$languageCode has invalid search tags.',
            );
            expect(
              item.localized(languageCode).sourceLabel,
              item.sourceLabel,
              reason: 'Official organisation names stay canonical.',
            );
          }
        }
      },
    );

    test(
      'localized search checks translated and canonical English content',
      () async {
        final items = await const CommunityRepository().load();
        final bayBug = items.singleWhere((item) => item.id == 'baybug_rides');

        expect(bayBug.matches('骑行', languageCode: 'zh'), isTrue);
        expect(bayBug.matches('cycling', languageCode: 'zh'), isTrue);
        expect(bayBug.localized('zh').title, 'BayBUG 社交骑行');
        expect(bayBug.localized('fr').title, bayBug.title);
      },
    );

    test('sorts entries and rejects duplicate identifiers', () {
      const repository = CommunityRepository();
      final second = _validItem(id: 'second')..['sortOrder'] = 2;
      final first = _validItem(id: 'first')..['sortOrder'] = 1;

      final sorted = repository.parse(jsonEncode([second, first]));
      expect(sorted.map((item) => item.id), ['first', 'second']);

      expect(
        () => repository.parse(jsonEncode([first, first])),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects untrusted URL formats', () {
      const repository = CommunityRepository();
      final invalid = _validItem(officialUrl: 'not-a-web-address');

      expect(
        () => repository.parse(jsonEncode([invalid])),
        throwsA(isA<FormatException>()),
      );
    });

    test('matches useful discovery terms case-insensitively', () {
      final item = CommunityItem.fromJson(
        Map<String, dynamic>.from(
          _validItem(category: 'bushcare')
            ..['tags'] = ['native plants', 'volunteer'],
        ),
      );

      expect(item.matches('NATIVE'), isTrue);
      expect(item.matches('bushcare'), isTrue);
      expect(item.matches('swimming pool'), isFalse);
    });
  });

  testWidgets('Community screen searches and opens trusted details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bayBug = CommunityItem.fromJson(
      Map<String, dynamic>.from(
        _validItem(
            id: 'baybug',
            category: 'cycling',
            officialUrl: 'https://baybug.org.au/',
          )
          ..['title'] = 'BayBUG social rides'
          ..['sourceLabel'] = 'Canada Bay Bicycle User Group'
          ..['tags'] = ['cycling', 'social rides'],
      ),
    );
    final openMaker = CommunityItem.fromJson(
      Map<String, dynamic>.from(
        _validItem(id: 'open-maker', category: 'library')
          ..['title'] = 'Open Maker'
          ..['featured'] = false
          ..['sortOrder'] = 2,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityScreen(
          repository: _FakeCommunityRepository([bayBug, openMaker]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Community'), findsOneWidget);
    expect(find.text('2 trusted leads'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('community-search')),
      'BayBUG',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('BayBUG social rides'), findsOneWidget);
    expect(find.text('Open Maker'), findsNothing);

    await tester.ensureVisible(find.text('BayBUG social rides'));
    await tester.tap(find.text('BayBUG social rides'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Official source'), findsOneWidget);
    expect(find.text('Canada Bay Bicycle User Group'), findsWidgets);
    expect(find.text('https://baybug.org.au/'), findsOneWidget);
  });

  test('Community and Services UI catalogues have strict locale parity', () {
    for (final languageCode
        in CommunityServicesLocalizations.supportedLanguageCodes.where(
          (code) => code != 'en',
        )) {
      final localizations = CommunityServicesLocalizations(languageCode);
      for (final key in CommunityServicesLocalizations.requiredUiKeys) {
        expect(
          localizations.hasOwnTranslation(key),
          isTrue,
          reason: '$languageCode.$key must not use English fallback.',
        );
        expect(localizations.text(key).trim(), isNotEmpty);
      }
    }
  });

  testWidgets('Community content renders and searches in every locale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const cases = <({String languageCode, String query, String expectedTitle})>[
      (languageCode: 'zh', query: '骑行', expectedTitle: 'BayBUG 社交骑行'),
      (languageCode: 'ko', query: '자전거', expectedTitle: 'BayBUG 친목 라이딩'),
      (
        languageCode: 'it',
        query: 'ciclismo',
        expectedTitle: 'Uscite sociali BayBUG',
      ),
      (
        languageCode: 'hi',
        query: 'देशी पौधे',
        expectedTitle: 'Canada Bay Bushcare से जुड़ें',
      ),
    ];
    final repository = _FakeCommunityRepository(
      const CommunityRepository().parse(
        File('assets/data/community.json').readAsStringSync(),
      ),
    );

    for (final testCase in cases) {
      await tester.pumpWidget(
        _localizedApp(
          languageCode: testCase.languageCode,
          home: CommunityScreen(repository: repository),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.enterText(
        find.byKey(const ValueKey('community-search')),
        testCase.query,
      );
      await tester.pump();

      expect(
        find.text(testCase.expectedTitle),
        findsWidgets,
        reason: 'Locale ${testCase.languageCode} must display localized data.',
      );
    }
  });

  testWidgets('Community details use translated fields and actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeCommunityRepository(
      const CommunityRepository().parse(
        File('assets/data/community.json').readAsStringSync(),
      ),
    );
    await tester.pumpWidget(
      _localizedApp(
        languageCode: 'zh',
        home: CommunityScreen(repository: repository),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.enterText(
      find.byKey(const ValueKey('community-search')),
      '骑行',
    );
    await tester.pump();

    final title = find.text('BayBUG 社交骑行').last;
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('查看骑行和参加要求'), findsOneWidget);
    expect(find.text('地点'), findsOneWidget);
    expect(find.text('BayBUG social rides'), findsNothing);
  });
}

Widget _localizedApp({required String languageCode, required Widget home}) {
  return MaterialApp(
    key: ValueKey(languageCode),
    locale: Locale(languageCode),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}
