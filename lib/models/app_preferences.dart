import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-side preferences used before a remote account service is connected.
///
/// These values are deliberately separate from passport progress so a future
/// authenticated preferences repository can replace this class cleanly.
class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _onboardingKey = 'app.onboarding.complete';
  static const _localeKey = 'app.locale';
  static const _residentTypeKey = 'app.onboarding.resident_type';
  static const _interestsKey = 'app.onboarding.interests';

  final SharedPreferencesAsync _preferences;

  bool _onboardingComplete = false;
  Locale _locale = const Locale('en');
  String _residentType = 'New resident';
  Set<String> _interests = <String>{'Community', 'Outdoors', 'Local services'};

  bool get onboardingComplete => _onboardingComplete;
  Locale get locale => _locale;
  String get residentType => _residentType;
  Set<String> get interests => Set<String>.unmodifiable(_interests);

  Future<void> load() async {
    try {
      _onboardingComplete = await _preferences.getBool(_onboardingKey) ?? false;
      _locale = Locale(await _preferences.getString(_localeKey) ?? 'en');
      _residentType =
          await _preferences.getString(_residentTypeKey) ?? 'New resident';
      _interests =
          (await _preferences.getStringList(_interestsKey) ??
                  <String>['Community', 'Outdoors', 'Local services'])
              .toSet();
    } on Object catch (error) {
      debugPrint('App preferences could not be restored: $error');
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = Locale(locale.languageCode);
    notifyListeners();
    await _preferences.setString(_localeKey, _locale.languageCode);
  }

  Future<void> completeOnboarding({
    required String residentType,
    required Set<String> interests,
  }) async {
    _residentType = residentType.trim().isEmpty
        ? 'New resident'
        : residentType.trim();
    _interests = interests.isEmpty
        ? <String>{'Community', 'Outdoors', 'Local services'}
        : Set<String>.of(interests);
    _onboardingComplete = true;
    notifyListeners();

    await Future.wait([
      _preferences.setString(_residentTypeKey, _residentType),
      _preferences.setStringList(_interestsKey, _interests.toList()..sort()),
      _preferences.setBool(_onboardingKey, true),
    ]);
  }

  Future<void> resetOnboarding() async {
    _onboardingComplete = false;
    notifyListeners();
    await _preferences.setBool(_onboardingKey, false);
  }
}
