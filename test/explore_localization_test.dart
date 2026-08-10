import 'dart:convert';
import 'dart:io';

import 'package:explore_canada_bay/l10n/app_localizations.dart';
import 'package:explore_canada_bay/l10n/explore_localizations.dart';
import 'package:explore_canada_bay/screens/explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

class _TransparentTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(TileProvider.transparentImage);
  }
}

Future<String> _fileAssetLoader(String path) => File(path).readAsString();

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = 60,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 80));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const localeCodes = ['zh', 'ko', 'it', 'hi'];
  const datasets = [
    'locations',
    'environment',
    'biodiversity',
    'routes',
    'food',
  ];
  const narrativeFields = {
    'description',
    'learningPrompt',
    'accessibility',
    'highlights',
  };
  const protectedTechnicalFields = {
    'id',
    'type',
    'placeId',
    'lat',
    'lng',
    'officialUrl',
    'image',
    'gpx',
    'xp',
    'rating',
    'stops',
    'scientificName',
  };

  test('every Explore locale owns every required UI key', () {
    final englishKeys = ExploreLocalizations.ownTranslationKeys('en');
    expect(englishKeys, containsAll(ExploreLocalizations.requiredUiKeys));

    for (final code in localeCodes) {
      final ownKeys = ExploreLocalizations.ownTranslationKeys(code);
      expect(
        ownKeys,
        containsAll(ExploreLocalizations.requiredUiKeys),
        reason: '$code must define every Explore UI string itself.',
      );
      for (final key in ExploreLocalizations.requiredUiKeys) {
        expect(
          ExploreLocalizations.hasOwnTranslation(code, key),
          isTrue,
          reason: '$code.$key must not pass through English fallback.',
        );
        final value = ExploreLocalizations(Locale(code)).text(key);
        expect(value.trim(), isNotEmpty, reason: '$code.$key is blank.');
        expect(value, isNot(contains('\uFFFD')));
      }
    }
  });

  test('production Explore content has strict per-field locale parity', () {
    for (final dataset in datasets) {
      final decoded = jsonDecode(
        File('assets/data/$dataset.json').readAsStringSync(),
      );
      expect(decoded, isA<List<dynamic>>());
      final records = decoded as List<dynamic>;
      final ids = <String>{};

      for (final raw in records) {
        expect(raw, isA<Map<String, dynamic>>());
        final record = raw as Map<String, dynamic>;
        final id = record['id'];
        expect(id, isA<String>(), reason: '$dataset record needs an id.');
        expect((id as String).trim(), isNotEmpty);
        expect(ids.add(id), isTrue, reason: '$dataset has duplicate id $id.');

        final translations = record['translations'];
        expect(
          translations,
          isA<Map<String, dynamic>>(),
          reason: '$dataset.$id needs translations.',
        );

        for (final code in localeCodes) {
          final localeContent = (translations as Map<String, dynamic>)[code];
          expect(
            localeContent,
            isA<Map<String, dynamic>>(),
            reason: '$dataset.$id.$code needs its own object.',
          );
          final translated = localeContent as Map<String, dynamic>;

          for (final technicalField in protectedTechnicalFields) {
            expect(
              translated.containsKey(technicalField),
              isFalse,
              reason: '$dataset.$id.$code must not translate $technicalField.',
            );
          }

          for (final field in ExploreLocalizations.translatableContentFields) {
            final base = record[field];
            final baseIsPresent = switch (base) {
              String value => value.trim().isNotEmpty,
              List<dynamic> value => value.isNotEmpty,
              _ => false,
            };
            if (!baseIsPresent) continue;

            expect(
              translated.containsKey(field),
              isTrue,
              reason: '$dataset.$id.$code.$field is missing.',
            );
            final value = translated[field];
            if (base is List<dynamic>) {
              expect(value, isA<List<dynamic>>());
              final translatedList = value as List<dynamic>;
              expect(
                translatedList.length,
                base.length,
                reason: '$dataset.$id.$code.$field changed item count.',
              );
              expect(
                translatedList.every(
                  (item) => item is String && item.trim().isNotEmpty,
                ),
                isTrue,
              );
              expect(translatedList.join(' '), isNot(contains('\uFFFD')));
            } else {
              expect(value, isA<String>());
              expect((value as String).trim(), isNotEmpty);
              expect(value, isNot(contains('\uFFFD')));
            }

            if (narrativeFields.contains(field)) {
              expect(
                value,
                isNot(equals(base)),
                reason: '$dataset.$id.$code.$field is still English.',
              );
            }
          }
        }
      }
    }
  });

  test(
    'content resolver keeps technical values and searches both languages',
    () {
      final routes =
          jsonDecode(File('assets/data/routes.json').readAsStringSync())
              as List<dynamic>;
      final bayRun = routes.first as Map<String, dynamic>;
      const zh = ExploreLocalizations(Locale('zh'));
      final translated = zh.contentFor(bayRun);

      expect(translated['id'], bayRun['id']);
      expect(translated['category'], '步行');
      expect(bayRun['category'], 'Walking');
      expect(zh.searchableText(bayRun), contains('海湾环线'));
      expect(zh.searchableText(bayRun), contains('Bay Run'));

      final fixture = <String, dynamic>{
        'id': 'fixture',
        'name': 'English fallback',
      };
      expect(zh.contentFor(fixture)['name'], 'English fallback');
    },
  );

  testWidgets('Explore renders and searches every supported content language', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 820);
    addTearDown(tester.view.reset);

    const cases =
        <
          String,
          ({
            String route,
            String filter,
            String viewRoute,
            String viewing,
            String query,
            String result,
          })
        >{
          'zh': (
            route: '海湾环线',
            filter: '骑行',
            viewRoute: '查看路线',
            viewing: '正在查看',
            query: '彩虹',
            result: '彩虹吸蜜鹦鹉',
          ),
          'ko': (
            route: '베이 런 순환로',
            filter: '자전거',
            viewRoute: '경로 보기',
            viewing: '보는 중',
            query: '맹그로브',
            result: '회색맹그로브',
          ),
          'it': (
            route: 'Anello della baia',
            filter: 'Bicicletta',
            viewRoute: 'Vedi percorso',
            viewing: 'In visualizzazione',
            query: 'mangrovia',
            result: 'Mangrovia grigia',
          ),
          'hi': (
            route: 'बे रन परिक्रमा',
            filter: 'साइकिल',
            viewRoute: 'मार्ग देखें',
            viewing: 'देख रहे हैं',
            query: 'मैंग्रोव',
            result: 'ग्रे मैंग्रोव',
          ),
        };

    for (final entry in cases.entries) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.key),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ExploreScreen(
            tileProvider: _TransparentTileProvider(),
            assetLoader: _fileAssetLoader,
          ),
        ),
      );
      await _pumpUntilFound(tester, find.text(entry.value.route));
      expect(find.text(entry.value.filter), findsOneWidget);
      expect(find.text(entry.value.viewRoute), findsWidgets);
      expect(
        tester.takeException(),
        isNull,
        reason: '${entry.key} unselected route card overflowed.',
      );

      await tester.tap(find.byKey(const ValueKey('view-route:bay_run')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(entry.value.viewing), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: '${entry.key} selected route card overflowed.',
      );

      await tester.enterText(find.byType(TextField), entry.value.query);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(entry.value.result), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('translated route actions fit compact mobile cards', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    const cases = <String, ({String route, String viewRoute, String viewing})>{
      'zh': (route: '海湾环线', viewRoute: '查看路线', viewing: '正在查看'),
      'ko': (route: '베이 런 순환로', viewRoute: '경로 보기', viewing: '보는 중'),
      'it': (
        route: 'Anello della baia',
        viewRoute: 'Vedi percorso',
        viewing: 'In visualizzazione',
      ),
      'hi': (
        route: 'बे रन परिक्रमा',
        viewRoute: 'मार्ग देखें',
        viewing: 'देख रहे हैं',
      ),
    };

    for (final entry in cases.entries) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.key),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ExploreScreen(
            tileProvider: _TransparentTileProvider(),
            assetLoader: _fileAssetLoader,
          ),
        ),
      );
      await _pumpUntilFound(tester, find.text(entry.value.route));
      expect(find.text(entry.value.viewRoute), findsWidgets);
      expect(
        tester.takeException(),
        isNull,
        reason: '${entry.key} compact unselected route card overflowed.',
      );

      await tester.tap(find.byKey(const ValueKey('view-route:bay_run')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(entry.value.viewing), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: '${entry.key} compact selected route card overflowed.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
