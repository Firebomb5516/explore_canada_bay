import 'package:explore_canada_bay/models/app_preferences.dart';
import 'package:explore_canada_bay/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  for (final size in <Size>[const Size(390, 844), const Size(1200, 800)]) {
    testWidgets('onboarding completes all steps without overflow at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      final preferences = _FakePreferences();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: OnboardingScreen(preferences: preferences),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose the language that feels right'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tapPrimaryAction(tester);
      expect(find.text('Tell us what brings you here'), findsOneWidget);
      await tester.tap(find.text('Student'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _tapPrimaryAction(tester);
      expect(find.text('What would help you settle in?'), findsOneWidget);
      await tester.tap(find.text('Environment'));
      await tester.pumpAndSettle();

      await _tapPrimaryAction(tester);
      expect(preferences.didComplete, isTrue);
      expect(preferences.completedResidentType, 'Student');
      expect(preferences.completedInterests, contains('Environment'));
    });
  }
}

Future<void> _tapPrimaryAction(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('onboarding-primary-action'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

class _FakePreferences extends AppPreferencesController {
  Locale _testLocale = const Locale('en');
  String _testResidentType = 'New resident';
  Set<String> _testInterests = <String>{
    'Community',
    'Outdoors',
    'Local services',
  };

  bool didComplete = false;
  String? completedResidentType;
  Set<String>? completedInterests;

  @override
  Locale get locale => _testLocale;

  @override
  String get residentType => _testResidentType;

  @override
  Set<String> get interests => Set<String>.unmodifiable(_testInterests);

  @override
  Future<void> setLocale(Locale locale) async {
    _testLocale = locale;
    notifyListeners();
  }

  @override
  Future<void> completeOnboarding({
    required String residentType,
    required Set<String> interests,
  }) async {
    _testResidentType = residentType;
    _testInterests = Set<String>.of(interests);
    completedResidentType = residentType;
    completedInterests = Set<String>.of(interests);
    didComplete = true;
    notifyListeners();
  }
}
