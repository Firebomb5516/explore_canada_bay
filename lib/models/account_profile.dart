import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Account-facing preferences that are useful before remote authentication is
/// connected. The controller can later be hydrated by an account repository
/// without changing the profile screen's public API.
class AccountProfileController extends ChangeNotifier {
  AccountProfileController({
    SharedPreferencesAsync? preferences,
    SupabaseClient? supabase,
  }) : this._internal(preferences ?? SharedPreferencesAsync(), supabase);

  AccountProfileController._internal(this._preferences, this._supabase);

  static const _nameKey = 'account.profile.name';
  static const _emailKey = 'account.profile.email';
  static const _themeKey = 'account.preferences.theme';
  static const _visibleKey = 'account.privacy.profile_visible';
  static const _achievementsKey = 'account.privacy.show_achievements';

  final SharedPreferencesAsync _preferences;
  final SupabaseClient? _supabase;

  String _name = 'Explorer';
  String _email = 'Not signed in';
  String? _userId;
  ThemeMode _themeMode = ThemeMode.light;
  bool _profileVisible = true;
  bool _showAchievements = true;

  String get name => _name;
  String get email => _email;
  ThemeMode get themeMode => _themeMode;
  bool get profileVisible => _profileVisible;
  bool get showAchievements => _showAchievements;
  bool get isSignedIn => _userId != null;
  bool get onlineAccountsAvailable => _supabase != null;

  /// Stable owner used to isolate device-side passport progress per account.
  /// Replace the email with the authentication provider's immutable user ID
  /// when the remote account service is connected.
  String get passportOwnerId => _userId ?? 'guest';

  Future<void> load() async {
    try {
      _name = await _preferences.getString(_nameKey) ?? 'Explorer';
      _email = await _preferences.getString(_emailKey) ?? 'Not signed in';
      _profileVisible = await _preferences.getBool(_visibleKey) ?? true;
      _showAchievements = await _preferences.getBool(_achievementsKey) ?? true;

      final savedTheme = await _preferences.getString(_themeKey);
      _themeMode = switch (savedTheme) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.light,
      };

      final user = _supabase?.auth.currentUser;
      if (user != null) {
        await _applySupabaseUser(user);
      }
    } on Object catch (error) {
      debugPrint('Account preferences could not be restored: $error');
    }

    notifyListeners();
  }

  Future<void> updateName(String value) async {
    final cleaned = value.trim();
    if (cleaned.isEmpty || cleaned == _name) return;

    _name = cleaned;
    notifyListeners();
    await _saveString(_nameKey, cleaned);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;

    _themeMode = value;
    notifyListeners();
    await _saveString(_themeKey, value.name);
  }

  Future<void> setProfileVisible(bool value) async {
    if (_profileVisible == value) return;

    _profileVisible = value;
    notifyListeners();
    await _saveBool(_visibleKey, value);
  }

  Future<void> setShowAchievements(bool value) async {
    if (_showAchievements == value) return;

    _showAchievements = value;
    notifyListeners();
    await _saveBool(_achievementsKey, value);
  }

  /// Used later after a successful OTP verification and profile fetch.
  Future<void> applyAuthenticatedProfile({
    required String name,
    required String email,
  }) async {
    _name = name.trim().isEmpty ? 'Explorer' : name.trim();
    _email = email.trim();
    notifyListeners();

    await Future.wait([
      _saveString(_nameKey, _name),
      _saveString(_emailKey, _email),
    ]);
  }

  Future<bool> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final client = _requireSupabase();
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
    );
    if (response.session != null && response.user != null) {
      await _applySupabaseUser(response.user!);
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _requireSupabase().auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign in did not return a user.');
    }
    await _applySupabaseUser(user);
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) async {
    await _requireSupabase().auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() async {
    await _supabase?.auth.signOut();
    _name = 'Explorer';
    _email = 'Not signed in';
    _userId = null;
    notifyListeners();
    await Future.wait([
      _saveString(_nameKey, _name),
      _saveString(_emailKey, _email),
    ]);
  }

  SupabaseClient _requireSupabase() {
    final client = _supabase;
    if (client == null) {
      throw const AuthException(
        'Online accounts are unavailable in this build.',
      );
    }
    return client;
  }

  Future<void> _applySupabaseUser(User user) async {
    final metadataName = user.userMetadata?['display_name']?.toString().trim();
    _userId = user.id;
    _name = metadataName == null || metadataName.isEmpty
        ? (_name == 'Explorer' ? 'Explorer' : _name)
        : metadataName;
    _email = user.email ?? 'Signed in';
    await Future.wait([
      _saveString(_nameKey, _name),
      _saveString(_emailKey, _email),
    ]);
  }

  Future<void> _saveString(String key, String value) async {
    try {
      await _preferences.setString(key, value);
    } on Object catch (error) {
      debugPrint('Account preference could not be saved: $error');
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      await _preferences.setBool(key, value);
    } on Object catch (error) {
      debugPrint('Account preference could not be saved: $error');
    }
  }
}
