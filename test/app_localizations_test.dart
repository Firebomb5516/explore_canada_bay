import 'dart:convert';
import 'dart:io';

import 'package:explore_canada_bay/l10n/app_localizations.dart';
import 'package:explore_canada_bay/models/passport.dart';
import 'package:explore_canada_bay/widgets/localized_text.dart' as localized;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const interfaceKeys = <String>{
    'home',
    'explore',
    'community',
    'services',
    'passport',
    'scan',
    'profile',
    'continue',
    'welcomeTitle',
    'welcomeBody',
    'aboutYou',
    'interests',
    'language',
    'newResident',
    'student',
    'family',
    'professional',
    'retiree',
    'communityInterest',
    'outdoorsInterest',
    'environmentInterest',
    'foodInterest',
    'servicesInterest',
  };

  test('every supported locale provides every interface string', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final localizations = AppLocalizations(locale);

      for (final key in interfaceKeys) {
        final value = localizations.text(key);
        expect(
          value.trim(),
          isNotEmpty,
          reason: '${locale.languageCode}.$key must not be empty.',
        );
        expect(
          value,
          isNot(key),
          reason: '${locale.languageCode}.$key must be defined.',
        );
        expect(
          value,
          isNot(contains('\uFFFD')),
          reason: '${locale.languageCode}.$key contains invalid Unicode.',
        );
      }
    }
  });

  test('translated onboarding copy retains native Unicode text', () {
    const expectedTitles = <String, String>{
      'zh': '让加拿大湾成为您的家',
      'ko': '캐나다 베이를 우리 동네로 만들어 보세요',
      'it': 'Fai di Canada Bay la tua casa',
      'hi': 'कनाडा बे को अपना घर बनाएँ',
    };

    for (final entry in expectedTitles.entries) {
      expect(
        AppLocalizations(Locale(entry.key)).text('welcomeTitle'),
        entry.value,
      );
    }
  });

  test('unsupported locales fall back to English', () {
    expect(
      const AppLocalizations(Locale('fr')).text('welcomeTitle'),
      'Make Canada Bay feel like home',
    );
  });

  test('primary screen literals do not bypass the selected language', () {
    const phrases = <String>[
      'Community Passport',
      'Scan & Discover',
      'Everyday essentials',
      'On Display',
      'Community collections',
      'Recent Discoveries',
      'Official source',
    ];

    for (final locale in AppLocalizations.supportedLocales.skip(1)) {
      final localizations = AppLocalizations(locale);
      for (final phrase in phrases) {
        expect(
          localizations.literal(phrase),
          isNot(phrase),
          reason: '${locale.languageCode} must translate "$phrase".',
        );
      }
    }
  });

  test('every registered app-owned phrase is complete in every locale', () {
    for (final locale in AppLocalizations.supportedLocales.skip(1)) {
      final languageCode = locale.languageCode;

      for (final key in AppLocalizations.requiredTextKeys) {
        expect(
          AppLocalizations.hasOwnTranslation(languageCode, key),
          isTrue,
          reason: '$languageCode must define the keyed message "$key".',
        );
      }
      for (final source in AppLocalizations.requiredScreenPhrases) {
        expect(
          AppLocalizations.hasScreenPhraseTranslation(languageCode, source),
          isTrue,
          reason: '$languageCode must translate "$source".',
        );
      }
      for (final source in AppLocalizations.requiredDynamicPhrases) {
        expect(
          AppLocalizations.hasDynamicPhraseTranslation(languageCode, source),
          isTrue,
          reason: '$languageCode must translate dynamic phrase "$source".',
        );
      }
      for (final source in AppLocalizations.requiredInterfaceLiterals) {
        expect(
          AppLocalizations.hasInterfaceLiteralTranslation(languageCode, source),
          isTrue,
          reason: '$languageCode must translate legacy phrase "$source".',
        );
      }
    }
  });

  test('shared screens retain exact native-script translations', () {
    expect(const AppLocalizations(Locale('zh')).literal('Appearance'), '外观');
    expect(
      const AppLocalizations(Locale('ko')).literal('Camera unavailable'),
      '카메라 사용 불가',
    );
    expect(
      const AppLocalizations(Locale('it')).literal('How your passport works'),
      'Come funziona il passaporto',
    );
    expect(
      const AppLocalizations(Locale('hi')).literal('Coming Soon'),
      'जल्द आ रहा है',
    );
  });

  test('known physical QR education copy is translated', () {
    const expectedTitles = <String, String>{
      'zh': '湿地栖息地',
      'ko': '습지 서식지',
      'it': 'Habitat delle zone umide',
      'hi': 'आर्द्रभूमि आवास',
    };

    for (final entry in expectedTitles.entries) {
      final strings = AppLocalizations(Locale(entry.key));
      expect(strings.literal('Wetland habitat'), entry.value);
      expect(
        strings.literal(
          'Mangroves and saltmarsh provide habitat for local wildlife.',
        ),
        isNot('Mangroves and saltmarsh provide habitat for local wildlife.'),
      );
      expect(strings.literal('Environment'), isNot('Environment'));
    }
  });

  test('reward and malformed-QR feedback are localized structurally', () {
    for (final locale in AppLocalizations.supportedLocales.skip(1)) {
      final strings = AppLocalizations(locale);
      expect(
        strings.rewardMessage(
          placeName: 'Cabarita Park',
          xp: 40,
          duplicate: false,
          badgeJustEarned: true,
          badgeName: strings.literal('Nature Trail'),
        ),
        isNot(contains('Badge unlocked')),
      );
      expect(
        strings.qrError('The scanned value must be a JSON object.'),
        isNot('The scanned value must be a JSON object.'),
      );
    }
  });

  test('every badge catalogue entry contains complete translations', () {
    final decoded =
        jsonDecode(File('assets/data/badges.json').readAsStringSync())
            as List<dynamic>;

    for (final raw in decoded) {
      final badgeJson = Map<String, dynamic>.from(raw as Map);
      final badge = PassportBadge.fromCatalogJson(badgeJson);
      for (final languageCode in const ['zh', 'ko', 'it', 'hi']) {
        final translation = badge.translations[languageCode];
        expect(
          translation,
          isNotNull,
          reason: '${badge.id} must define $languageCode translations.',
        );
        for (final field in const [
          'name',
          'description',
          'category',
          'collection',
          'rarity',
        ]) {
          expect(
            translation![field]?.trim(),
            isNotEmpty,
            reason: '${badge.id}.$languageCode.$field must be translated.',
          );
        }
      }
    }

    final natureBadge = PassportBadge.fromCatalogJson(
      Map<String, dynamic>.from(
        decoded.cast<Map>().firstWhere(
          (badge) => badge['id'] == 'nature_trail',
        ),
      ),
    );
    expect(natureBadge.localizedName('zh'), '自然步道');
    expect(natureBadge.localizedName('ko'), '자연 탐방로');
    expect(natureBadge.localizedName('it'), 'Sentiero natura');
    expect(natureBadge.localizedName('hi'), 'प्रकृति पथ');
  });

  testWidgets('localized Text renders the selected locale on every screen', (
    tester,
  ) async {
    const expected = <String, String>{
      'en': 'Coming Soon',
      'zh': '即将推出',
      'ko': '곧 제공됩니다',
      'it': 'Prossimamente',
      'hi': 'जल्द आ रहा है',
    };

    for (final entry in expected.entries) {
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
          home: const Scaffold(body: localized.Text('Coming Soon')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(entry.value, findRichText: true),
        findsOneWidget,
        reason: '${entry.key} must render translated widget text.',
      );
    }
  });

  test('form labels, tooltips and semantics cannot bypass localization', () {
    for (final path in const [
      'lib/screens/home_screen.dart',
      'lib/screens/onboarding_screen.dart',
      'lib/screens/profile_screen.dart',
      'lib/screens/passport_screen.dart',
      'lib/screens/scan_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final property in const [
        'labelText',
        'helperText',
        'tooltip',
        'semanticLabel',
      ]) {
        expect(
          RegExp("$property\\s*:\\s*['\\\"]").hasMatch(source),
          isFalse,
          reason: '$path must localize every $property value.',
        );
      }
    }
  });
}
