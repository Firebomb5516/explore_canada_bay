import 'dart:convert';
import 'dart:io';

import 'package:explore_canada_bay/l10n/app_localizations.dart';
import 'package:explore_canada_bay/models/local_service_item.dart';
import 'package:explore_canada_bay/screens/local_services_screen.dart';
import 'package:explore_canada_bay/services/local_services_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Local services catalogue', () {
    late LocalServicesCatalog catalog;

    setUpAll(() {
      final json =
          jsonDecode(File('assets/data/local_services.json').readAsStringSync())
              as Map<String, dynamic>;
      catalog = LocalServicesCatalog.fromJson(json);
    });

    test('covers every Product Brief service area', () {
      expect(
        catalog.services.map((service) => service.id),
        containsAll(<String>[
          'bin-collection',
          'recycling-stations',
          'park-barbecues',
          'libraries',
          'public-transport',
          'parking-permits',
          'public-toilets',
          'emergency-help',
          'report-council-issue',
          'dog-off-leash',
        ]),
      );
    });

    test('uses valid official HTTPS links and unique ids', () {
      final ids = catalog.services.map((service) => service.id).toSet();
      expect(ids, hasLength(catalog.services.length));

      for (final service in catalog.services) {
        final uri = Uri.parse(service.officialUrl);
        expect(uri.scheme, 'https', reason: service.id);
        expect(uri.hasAuthority, isTrue, reason: service.id);
        expect(service.sourceLabel, isNotEmpty, reason: service.id);
      }
    });

    test(
      'bundled services contain complete content for every app language',
      () {
        for (final service in catalog.services) {
          expect(
            service.translations.keys.toSet(),
            containsAll(LocalServiceItem.requiredTranslationLanguageCodes),
            reason: '${service.id} must contain every supported translation.',
          );
          for (final languageCode
              in LocalServiceItem.requiredTranslationLanguageCodes) {
            final translation = service.translations[languageCode];
            expect(
              translation,
              isNotNull,
              reason: '${service.id}.$languageCode is missing.',
            );
            final scalarFields = <String>[
              translation!.title,
              translation.summary,
              translation.details,
              translation.actionLabel,
            ];
            expect(
              scalarFields.every((value) => value.trim().isNotEmpty),
              isTrue,
              reason: '${service.id}.$languageCode has empty display text.',
            );
            expect(
              scalarFields.any((value) => value.contains('\uFFFD')),
              isFalse,
              reason: '${service.id}.$languageCode contains invalid Unicode.',
            );
            expect(
              translation.highlights.every((value) => value.trim().isNotEmpty),
              isTrue,
              reason: '${service.id}.$languageCode has invalid highlights.',
            );
            expect(
              translation.keywords.every((value) => value.trim().isNotEmpty),
              isTrue,
              reason: '${service.id}.$languageCode has invalid search terms.',
            );
            expect(
              service.localized(languageCode).sourceLabel,
              service.sourceLabel,
              reason: 'Official organisation names stay canonical.',
            );
          }
        }
      },
    );

    test('keeps emergency guidance singular and explicit', () {
      final emergency = catalog.services.singleWhere(
        (service) => service.isEmergency,
      );

      expect(emergency.phone, '000');
      expect(emergency.isEssential, isTrue);
      expect(emergency.details, contains('131 444'));
      expect(emergency.details, contains('132 500'));
    });

    test('supports keyword discovery', () {
      final bins = catalog.services.singleWhere(
        (service) => service.id == 'bin-collection',
      );
      final toilets = catalog.services.singleWhere(
        (service) => service.id == 'public-toilets',
      );

      expect(bins.matches('missed bin'), isTrue);
      expect(toilets.matches('bathroom'), isTrue);
      expect(toilets.matches('parking permit'), isFalse);
    });

    test(
      'localized search checks translated and canonical English content',
      () {
        final renting = catalog.services.singleWhere(
          (service) => service.id == 'renting-rights',
        );

        expect(renting.matches('租房', languageCode: 'zh'), isTrue);
        expect(renting.matches('tenant', languageCode: 'zh'), isTrue);
        expect(renting.localized('zh').title, '新州租房权利');
        expect(renting.localized('fr').title, renting.title);
      },
    );

    test('rejects duplicate service ids', () {
      final service = _validServiceJson();
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'lastReviewed': '2026-07-24',
        'services': [
          service,
          Map<String, dynamic>.from(service),
          _validEmergencyJson(),
        ],
      };

      expect(
        () => LocalServicesCatalog.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('repository wraps malformed data with a useful error', () async {
    final repository = LocalServicesRepository(
      assetLoader: (_) async => '{"schemaVersion":',
    );

    await expectLater(
      repository.loadCatalog(),
      throwsA(
        isA<LocalServicesRepositoryException>().having(
          (error) => error.message,
          'message',
          contains('not valid JSON'),
        ),
      ),
    );
  });

  test('bundled repository loads the packaged JSON asset', () async {
    final catalog = await const LocalServicesRepository().loadCatalog();

    expect(catalog.schemaVersion, 1);
    expect(catalog.services, hasLength(14));
  });

  testWidgets('screen searches and opens official service details', (
    tester,
  ) async {
    final repository = LocalServicesRepository(
      assetLoader: (_) async =>
          File('assets/data/local_services.json').readAsStringSync(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: LocalServicesScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settle in with confidence'), findsOneWidget);
    expect(find.text('Know when to call Triple Zero'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pump();

    expect(find.text('Dog parks and off-leash areas'), findsOneWidget);
    expect(find.text('Parking and permits'), findsNothing);

    final dogParksResult = find.text('Dog parks and off-leash areas');
    await tester.ensureVisible(dogParksResult);
    await tester.pumpAndSettle();
    await tester.tap(dogParksResult);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'https://www.canadabay.nsw.gov.au/residents/animals/'
        'local-off-leash-areas',
      ),
      findsOneWidget,
    );
    expect(find.text('Find an off-leash area'), findsOneWidget);
  });

  testWidgets('screen renders without layout errors on mobile and desktop', (
    tester,
  ) async {
    final repository = LocalServicesRepository(
      assetLoader: (_) async =>
          File('assets/data/local_services.json').readAsStringSync(),
    );

    for (final size in <Size>[const Size(390, 844), const Size(1440, 1000)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: LocalServicesScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settle in with confidence'), findsOneWidget);
      expect(find.text('Everyday essentials'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('service content renders and searches in every locale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const cases = <({String languageCode, String query, String expectedTitle})>[
      (languageCode: 'zh', query: '租房', expectedTitle: '新州租房权利'),
      (languageCode: 'ko', query: '반려견', expectedTitle: '반려견 공원과 목줄 해제 구역'),
      (
        languageCode: 'it',
        query: 'riciclaggio',
        expectedTitle: 'Riciclaggio e rifiuti problematici',
      ),
      (
        languageCode: 'hi',
        query: 'दुभाषिया',
        expectedTitle: 'दुभाषिया और भाषा सहायता',
      ),
    ];

    for (final testCase in cases) {
      await tester.pumpWidget(_localizedServicesApp(testCase.languageCode));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.enterText(find.byType(TextField), testCase.query);
      await tester.pump();

      expect(
        find.text(testCase.expectedTitle),
        findsWidgets,
        reason: 'Locale ${testCase.languageCode} must display localized data.',
      );
    }
  });

  testWidgets('service details localize content, labels and actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_localizedServicesApp('zh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.enterText(find.byType(TextField), '租房');
    await tester.pump();

    final title = find.text('新州租房权利');
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(title);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(title);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('阅读租房指南'), findsOneWidget);
    expect(find.textContaining('官方来源'), findsWidgets);
    expect(find.text('Renting rights in NSW'), findsNothing);
  });
}

Widget _localizedServicesApp(String languageCode) {
  final repository = LocalServicesRepository(
    assetLoader: (_) async =>
        File('assets/data/local_services.json').readAsStringSync(),
  );
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
    home: LocalServicesScreen(repository: repository),
  );
}

Map<String, dynamic> _validServiceJson() => <String, dynamic>{
  'id': 'service',
  'title': 'Service',
  'category': 'council',
  'summary': 'Summary',
  'details': 'Details',
  'actionLabel': 'Copy link',
  'sourceLabel': 'Official source',
  'officialUrl': 'https://example.gov.au/service',
  'isEssential': false,
  'isEmergency': false,
  'sortOrder': 1,
  'highlights': ['Highlight'],
  'keywords': ['Keyword'],
};

Map<String, dynamic> _validEmergencyJson() => <String, dynamic>{
  'id': 'emergency',
  'title': 'Emergency',
  'category': 'emergency',
  'summary': 'Summary',
  'details': 'Details',
  'actionLabel': 'Copy link',
  'sourceLabel': 'NSW Government',
  'officialUrl': 'https://www.nsw.gov.au/emergency',
  'phone': '000',
  'isEssential': true,
  'isEmergency': true,
  'sortOrder': 0,
  'highlights': ['Call 000'],
  'keywords': ['Emergency'],
};
