import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Practical details a newcomer chooses to keep on this device.
///
/// This is deliberately separate from achievements: it turns the passport into
/// a useful local wallet as well as a record of exploration. Only a library card
/// label/last digits are stored; the app never stores a library PIN.
class SettlementProfileController extends ChangeNotifier {
  factory SettlementProfileController({
    SharedPreferencesAsync? preferences,
    SupabaseClient? supabase,
    String? userId,
  }) => SettlementProfileController._(
    preferences ?? SharedPreferencesAsync(),
    supabase,
    userId,
  );

  SettlementProfileController._(
    this._preferences,
    this._supabase,
    this._userId,
  );

  /// Creates a non-persisting controller for previews and widget tests.
  SettlementProfileController.memory() : this._(null, null, null);

  static const _libraryCardKey = 'settlement.library_card_label';
  static const _binDayKey = 'settlement.bin_day';
  static const _binReminderKey = 'settlement.bin_reminder';
  static const _tutorialSeenKey = 'settlement.tutorial_seen';
  static const _transportStopKey = 'settlement.transport_stop';
  static const _transportModeKey = 'settlement.transport_mode';
  static const _councilReportKey = 'settlement.council_report';
  static const _councilReportTypeKey = 'settlement.council_report_type';
  static const _petNameKey = 'settlement.pet_name';
  static const _journeyReminderKey = 'settlement.journey_reminders';
  static const _journeyResumePageKey = 'settlement.journey_resume_page';
  static const _journeyStartedAtKey = 'settlement.journey_started_at';
  static const defaultCouncilIssueType = 'council-issue';

  static bool isDefaultCouncilIssueType(String? value) =>
      value == null ||
      value == defaultCouncilIssueType ||
      value.trim().toLowerCase() == 'council issue';

  final SharedPreferencesAsync? _preferences;
  final SupabaseClient? _supabase;
  String? _userId;

  String? _libraryCardLabel;
  int? _binCollectionWeekday;
  bool _binReminderEnabled = false;
  bool _tutorialSeen = false;
  String? _transportStop;
  String? _transportMode;
  String? _councilReportReference;
  String? _councilReportType;
  String? _petName;
  bool _journeyRemindersEnabled = false;
  int _journeyResumePage = 0;
  DateTime? _journeyStartedAt;

  String? get libraryCardLabel => _libraryCardLabel;
  int? get binCollectionWeekday => _binCollectionWeekday;
  bool get binReminderEnabled => _binReminderEnabled;
  bool get tutorialSeen => _tutorialSeen;
  bool get hasLibraryCard => _libraryCardLabel?.isNotEmpty ?? false;
  bool get hasBinDay => _binCollectionWeekday != null;
  String? get transportStop => _transportStop;
  String? get transportMode => _transportMode;
  String? get councilReportReference => _councilReportReference;
  String? get councilReportType => _councilReportType;
  String? get petName => _petName;
  bool get hasTransportShortcut => _transportStop?.isNotEmpty ?? false;
  bool get hasCouncilReport => _councilReportReference?.isNotEmpty ?? false;
  bool get hasPetProfile => _petName?.isNotEmpty ?? false;
  bool get journeyRemindersEnabled => _journeyRemindersEnabled;
  int get journeyResumePage => _journeyResumePage;
  DateTime? get journeyStartedAt => _journeyStartedAt;
  bool get cloudSyncAvailable => _supabase != null;
  bool get isCloudAccount => _userId != null;

  String get binDayLabel => switch (_binCollectionWeekday) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    DateTime.sunday => 'Sunday',
    _ => 'Not set',
  };

  int get setupCompletedCount => (hasBinDay ? 1 : 0) + (hasLibraryCard ? 1 : 0);

  int get usefulToolCount =>
      setupCompletedCount +
      (hasTransportShortcut ? 1 : 0) +
      (hasCouncilReport ? 1 : 0) +
      (hasPetProfile ? 1 : 0);

  Future<void> load() async {
    final preferences = _preferences;
    if (preferences == null) {
      notifyListeners();
      return;
    }
    try {
      await _loadLocalProfile(preferences);
      _tutorialSeen = await preferences.getBool(_tutorialSeenKey) ?? false;
      await _loadCloudProfile();
    } on Object catch (error) {
      debugPrint('Settlement profile could not be restored: $error');
    }
    notifyListeners();
  }

  Future<void> switchAccount(String? userId) async {
    if (_userId == userId) return;
    _userId = userId;
    final preferences = _preferences;
    if (preferences != null) await _loadLocalProfile(preferences);
    if (userId != null) await _loadCloudProfile();
    notifyListeners();
  }

  Future<void> saveLibraryCard(String value) async {
    final cleaned = value.trim();
    _libraryCardLabel = cleaned.isEmpty ? null : cleaned;
    notifyListeners();
    final preferences = _preferences;
    if (preferences != null) {
      await _writeOptional(
        preferences,
        _profileKey(_libraryCardKey),
        _libraryCardLabel,
      );
    }
    await _pushCloudProfile();
  }

  Future<void> saveBinCollection({
    required int weekday,
    required bool reminderEnabled,
  }) async {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw ArgumentError.value(weekday, 'weekday');
    }
    _binCollectionWeekday = weekday;
    _binReminderEnabled = reminderEnabled;
    notifyListeners();
    final preferences = _preferences;
    if (preferences != null) {
      await Future.wait([
        preferences.setInt(_profileKey(_binDayKey), weekday),
        preferences.setBool(_profileKey(_binReminderKey), reminderEnabled),
      ]);
    }
    await _pushCloudProfile();
  }

  Future<void> setBinReminderEnabled(bool enabled) async {
    _binReminderEnabled = hasBinDay && enabled;
    notifyListeners();
    await _preferences?.setBool(
      _profileKey(_binReminderKey),
      _binReminderEnabled,
    );
  }

  Future<void> saveTransportShortcut({
    required String stop,
    required String mode,
  }) async {
    _transportStop = _clean(stop);
    _transportMode = _clean(mode);
    notifyListeners();
    final preferences = _preferences;
    if (preferences != null) {
      if (_transportStop == null) {
        await Future.wait([
          preferences.remove(_profileKey(_transportStopKey)),
          preferences.remove(_profileKey(_transportModeKey)),
        ]);
      } else {
        await Future.wait([
          preferences.setString(
            _profileKey(_transportStopKey),
            _transportStop!,
          ),
          preferences.setString(
            _profileKey(_transportModeKey),
            _transportMode ?? 'Public transport',
          ),
        ]);
      }
    }
    await _pushCloudProfile();
  }

  Future<void> saveCouncilReport({
    required String reference,
    required String type,
  }) async {
    _councilReportReference = _clean(reference);
    _councilReportType = _councilReportReference == null
        ? null
        : _clean(type) ?? defaultCouncilIssueType;
    notifyListeners();
    final preferences = _preferences;
    if (preferences != null) {
      if (_councilReportReference == null) {
        await Future.wait([
          preferences.remove(_profileKey(_councilReportKey)),
          preferences.remove(_profileKey(_councilReportTypeKey)),
        ]);
      } else {
        await Future.wait([
          preferences.setString(
            _profileKey(_councilReportKey),
            _councilReportReference!,
          ),
          preferences.setString(
            _profileKey(_councilReportTypeKey),
            _councilReportType!,
          ),
        ]);
      }
    }
    await _pushCloudProfile();
  }

  Future<void> savePetProfile(String name) async {
    _petName = _clean(name);
    notifyListeners();
    final preferences = _preferences;
    if (preferences != null) {
      await _writeOptional(preferences, _profileKey(_petNameKey), _petName);
    }
    await _pushCloudProfile();
  }

  Future<void> markTutorialSeen() async {
    if (_tutorialSeen) return;
    _tutorialSeen = true;
    notifyListeners();
    await _preferences?.setBool(_tutorialSeenKey, true);
  }

  Future<void> setJourneyRemindersEnabled(bool enabled) async {
    _journeyRemindersEnabled = enabled;
    notifyListeners();
    await _preferences?.setBool(_profileKey(_journeyReminderKey), enabled);
  }

  Future<void> saveJourneyResumePage(int page) async {
    _journeyResumePage = page.clamp(0, 50);
    notifyListeners();
    await _preferences?.setInt(
      _profileKey(_journeyResumePageKey),
      _journeyResumePage,
    );
    await _pushCloudProfile();
  }

  Future<DateTime> ensureJourneyStarted() async {
    final existing = _journeyStartedAt;
    if (existing != null) return existing;
    final now = DateTime.now();
    _journeyStartedAt = DateTime(now.year, now.month, now.day);
    notifyListeners();
    await _preferences?.setString(
      _profileKey(_journeyStartedAtKey),
      _journeyStartedAt!.toIso8601String(),
    );
    await _pushCloudProfile();
    return _journeyStartedAt!;
  }

  static String? _clean(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _loadLocalProfile(SharedPreferencesAsync preferences) async {
    _libraryCardLabel = await preferences.getString(
      _profileKey(_libraryCardKey),
    );
    _binCollectionWeekday = await preferences.getInt(_profileKey(_binDayKey));
    _binReminderEnabled =
        await preferences.getBool(_profileKey(_binReminderKey)) ?? false;
    _transportStop = await preferences.getString(
      _profileKey(_transportStopKey),
    );
    _transportMode = await preferences.getString(
      _profileKey(_transportModeKey),
    );
    _councilReportReference = await preferences.getString(
      _profileKey(_councilReportKey),
    );
    _councilReportType = await preferences.getString(
      _profileKey(_councilReportTypeKey),
    );
    _petName = await preferences.getString(_profileKey(_petNameKey));
    _journeyRemindersEnabled =
        await preferences.getBool(_profileKey(_journeyReminderKey)) ?? false;
    _journeyResumePage =
        await preferences.getInt(_profileKey(_journeyResumePageKey)) ?? 0;
    _journeyStartedAt = DateTime.tryParse(
      await preferences.getString(_profileKey(_journeyStartedAtKey)) ?? '',
    );

    final hasScopedProfile =
        _libraryCardLabel != null ||
        _binCollectionWeekday != null ||
        _transportStop != null ||
        _councilReportReference != null ||
        _petName != null;
    if (hasScopedProfile) return;

    // Migrate the pre-account local profile once, then remove the unscoped
    // values so a later account cannot accidentally inherit them.
    _libraryCardLabel = await preferences.getString(_libraryCardKey);
    _binCollectionWeekday = await preferences.getInt(_binDayKey);
    _binReminderEnabled =
        await preferences.getBool(_binReminderKey) ?? _binReminderEnabled;
    _transportStop = await preferences.getString(_transportStopKey);
    _transportMode = await preferences.getString(_transportModeKey);
    _councilReportReference = await preferences.getString(_councilReportKey);
    _councilReportType = await preferences.getString(_councilReportTypeKey);
    _petName = await preferences.getString(_petNameKey);
    final hasLegacyProfile =
        _libraryCardLabel != null ||
        _binCollectionWeekday != null ||
        _transportStop != null ||
        _councilReportReference != null ||
        _petName != null;
    if (!hasLegacyProfile) return;

    await _persistCloudValuesLocally();
    await Future.wait([
      preferences.remove(_libraryCardKey),
      preferences.remove(_binDayKey),
      preferences.remove(_binReminderKey),
      preferences.remove(_transportStopKey),
      preferences.remove(_transportModeKey),
      preferences.remove(_councilReportKey),
      preferences.remove(_councilReportTypeKey),
      preferences.remove(_petNameKey),
    ]);
  }

  String _profileKey(String key) {
    final owner = _userId;
    if (owner == null) return '$key.guest';
    final encoded = base64Url.encode(utf8.encode(owner)).replaceAll('=', '');
    return '$key.$encoded';
  }

  Future<void> _loadCloudProfile() async {
    final client = _supabase;
    final userId = _userId;
    if (client == null || userId == null) return;
    try {
      final row = await client
          .from('user_settlement_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) {
        await _pushCloudProfile();
        return;
      }
      final weekday = row['bin_collection_weekday'];
      _binCollectionWeekday =
          weekday is int &&
              weekday >= DateTime.monday &&
              weekday <= DateTime.sunday
          ? weekday
          : _binCollectionWeekday;
      _libraryCardLabel = _cloudText(row['library_card_label']);
      _transportStop = _cloudText(row['transport_stop']);
      _transportMode = _cloudText(row['transport_mode']);
      _councilReportReference = _cloudText(row['council_report_reference']);
      _councilReportType = _cloudText(row['council_report_type']);
      _petName = _cloudText(row['pet_name']);
      _journeyResumePage = row['journey_resume_page'] is int
          ? (row['journey_resume_page'] as int).clamp(0, 50)
          : _journeyResumePage;
      _journeyStartedAt =
          DateTime.tryParse(row['journey_started_at']?.toString() ?? '') ??
          _journeyStartedAt;
      notifyListeners();
      await _persistCloudValuesLocally();
    } on Object catch (error) {
      debugPrint('Account essentials could not be restored: $error');
    }
  }

  Future<void> _pushCloudProfile() async {
    final client = _supabase;
    final userId = _userId;
    if (client == null || userId == null) return;
    try {
      await client.from('user_settlement_profiles').upsert({
        'user_id': userId,
        'bin_collection_weekday': _binCollectionWeekday,
        'library_card_label': _libraryCardLabel,
        'transport_stop': _transportStop,
        'transport_mode': _transportMode,
        'council_report_reference': _councilReportReference,
        'council_report_type': _councilReportType,
        'pet_name': _petName,
        'journey_resume_page': _journeyResumePage,
        'journey_started_at': _journeyStartedAt?.toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on Object catch (error) {
      // Local persistence remains the offline source until the next save/load.
      debugPrint('Account essentials could not be synced: $error');
    }
  }

  Future<void> _persistCloudValuesLocally() async {
    final preferences = _preferences;
    if (preferences == null) return;
    final writes = <Future<void>>[];
    if (_binCollectionWeekday != null) {
      writes.add(
        preferences.setInt(_profileKey(_binDayKey), _binCollectionWeekday!),
      );
    }
    writes.add(
      preferences.setBool(_profileKey(_binReminderKey), _binReminderEnabled),
    );
    writes.add(
      _writeOptional(
        preferences,
        _profileKey(_libraryCardKey),
        _libraryCardLabel,
      ),
    );
    writes.add(
      _writeOptional(
        preferences,
        _profileKey(_transportStopKey),
        _transportStop,
      ),
    );
    writes.add(
      _writeOptional(
        preferences,
        _profileKey(_transportModeKey),
        _transportMode,
      ),
    );
    writes.add(
      _writeOptional(
        preferences,
        _profileKey(_councilReportKey),
        _councilReportReference,
      ),
    );
    writes.add(
      _writeOptional(
        preferences,
        _profileKey(_councilReportTypeKey),
        _councilReportType,
      ),
    );
    writes.add(_writeOptional(preferences, _profileKey(_petNameKey), _petName));
    writes.add(
      preferences.setInt(
        _profileKey(_journeyResumePageKey),
        _journeyResumePage,
      ),
    );
    if (_journeyStartedAt != null) {
      writes.add(
        preferences.setString(
          _profileKey(_journeyStartedAtKey),
          _journeyStartedAt!.toIso8601String(),
        ),
      );
    }
    await Future.wait(writes);
  }

  static Future<void> _writeOptional(
    SharedPreferencesAsync preferences,
    String key,
    String? value,
  ) => value == null
      ? preferences.remove(key)
      : preferences.setString(key, value);

  static String? _cloudText(Object? value) {
    if (value is! String) return null;
    return _clean(value);
  }
}
