import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Practical details a newcomer chooses to keep on this device.
///
/// This is deliberately separate from achievements: it turns the passport into
/// a useful local wallet as well as a record of exploration. Only a library card
/// label/last digits are stored; the app never stores a library PIN.
class SettlementProfileController extends ChangeNotifier {
  SettlementProfileController({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// Creates a non-persisting controller for previews and widget tests.
  SettlementProfileController.memory() : _preferences = null;

  static const _libraryCardKey = 'settlement.library_card_label';
  static const _binDayKey = 'settlement.bin_day';
  static const _binReminderKey = 'settlement.bin_reminder';
  static const _tutorialSeenKey = 'settlement.tutorial_seen';
  static const _transportStopKey = 'settlement.transport_stop';
  static const _transportModeKey = 'settlement.transport_mode';
  static const _councilReportKey = 'settlement.council_report';
  static const _councilReportTypeKey = 'settlement.council_report_type';
  static const _petNameKey = 'settlement.pet_name';
  static const defaultCouncilIssueType = 'council-issue';

  static bool isDefaultCouncilIssueType(String? value) =>
      value == null ||
      value == defaultCouncilIssueType ||
      value.trim().toLowerCase() == 'council issue';

  final SharedPreferencesAsync? _preferences;

  String? _libraryCardLabel;
  int? _binCollectionWeekday;
  bool _binReminderEnabled = false;
  bool _tutorialSeen = false;
  String? _transportStop;
  String? _transportMode;
  String? _councilReportReference;
  String? _councilReportType;
  String? _petName;

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
      _libraryCardLabel = await preferences.getString(_libraryCardKey);
      _binCollectionWeekday = await preferences.getInt(_binDayKey);
      _binReminderEnabled = await preferences.getBool(_binReminderKey) ?? false;
      _tutorialSeen = await preferences.getBool(_tutorialSeenKey) ?? false;
      _transportStop = await preferences.getString(_transportStopKey);
      _transportMode = await preferences.getString(_transportModeKey);
      _councilReportReference = await preferences.getString(_councilReportKey);
      _councilReportType = await preferences.getString(_councilReportTypeKey);
      _petName = await preferences.getString(_petNameKey);
    } on Object catch (error) {
      debugPrint('Settlement profile could not be restored: $error');
    }
    notifyListeners();
  }

  Future<void> saveLibraryCard(String value) async {
    final cleaned = value.trim();
    _libraryCardLabel = cleaned.isEmpty ? null : cleaned;
    notifyListeners();
    final preferences = _preferences;
    if (preferences == null) return;
    if (_libraryCardLabel == null) {
      await preferences.remove(_libraryCardKey);
    } else {
      await preferences.setString(_libraryCardKey, _libraryCardLabel!);
    }
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
    if (preferences == null) return;
    await Future.wait([
      preferences.setInt(_binDayKey, weekday),
      preferences.setBool(_binReminderKey, reminderEnabled),
    ]);
  }

  Future<void> setBinReminderEnabled(bool enabled) async {
    _binReminderEnabled = hasBinDay && enabled;
    notifyListeners();
    await _preferences?.setBool(_binReminderKey, _binReminderEnabled);
  }

  Future<void> saveTransportShortcut({
    required String stop,
    required String mode,
  }) async {
    _transportStop = _clean(stop);
    _transportMode = _clean(mode);
    notifyListeners();
    final preferences = _preferences;
    if (preferences == null) return;
    if (_transportStop == null) {
      await Future.wait([
        preferences.remove(_transportStopKey),
        preferences.remove(_transportModeKey),
      ]);
      return;
    }
    await Future.wait([
      preferences.setString(_transportStopKey, _transportStop!),
      preferences.setString(
        _transportModeKey,
        _transportMode ?? 'Public transport',
      ),
    ]);
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
    if (preferences == null) return;
    if (_councilReportReference == null) {
      await Future.wait([
        preferences.remove(_councilReportKey),
        preferences.remove(_councilReportTypeKey),
      ]);
      return;
    }
    await Future.wait([
      preferences.setString(_councilReportKey, _councilReportReference!),
      preferences.setString(_councilReportTypeKey, _councilReportType!),
    ]);
  }

  Future<void> savePetProfile(String name) async {
    _petName = _clean(name);
    notifyListeners();
    final preferences = _preferences;
    if (preferences == null) return;
    if (_petName == null) {
      await preferences.remove(_petNameKey);
    } else {
      await preferences.setString(_petNameKey, _petName!);
    }
  }

  Future<void> markTutorialSeen() async {
    if (_tutorialSeen) return;
    _tutorialSeen = true;
    notifyListeners();
    await _preferences?.setBool(_tutorialSeenKey, true);
  }

  static String? _clean(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}
