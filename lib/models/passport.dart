import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A badge displayed in the explorer's digital passport.
@immutable
class PassportBadge {
  const PassportBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.iconName,
    required this.colourValue,
    required this.target,
    required this.progress,
    this.collection = 'General',
    this.imageAsset,
    this.sortOrder = 0,
    this.rarity = 'Common',
    this.translations = const <String, Map<String, String>>{},
  });

  factory PassportBadge.fromJson(Map<String, dynamic> json) {
    final target = _requiredInt(
      json,
      'target',
      minimum: 1,
      maximum: 50,
      context: 'badge',
    );
    final progress = _requiredInt(
      json,
      'progress',
      minimum: 0,
      maximum: target,
      context: 'badge',
    );

    return PassportBadge(
      id: _requiredString(json, 'id', maximumLength: 80, context: 'badge'),
      name: _requiredString(json, 'name', maximumLength: 80, context: 'badge'),
      description: _requiredString(
        json,
        'description',
        maximumLength: 240,
        context: 'badge',
      ),
      category: _requiredString(
        json,
        'category',
        maximumLength: 50,
        context: 'badge',
      ),
      iconName: _requiredString(
        json,
        'iconName',
        maximumLength: 80,
        context: 'badge',
      ),
      colourValue: _requiredInt(
        json,
        'colourValue',
        minimum: 0,
        maximum: 0xFFFFFFFF,
        context: 'badge',
      ),
      target: target,
      progress: progress,
      collection: json['collection'] is String
          ? (json['collection'] as String).trim()
          : 'General',
      imageAsset: json['imageAsset'] is String
          ? (json['imageAsset'] as String).trim()
          : null,
      sortOrder: json['sortOrder'] is int ? json['sortOrder'] as int : 0,
      rarity: json['rarity'] is String ? json['rarity'] as String : 'Common',
      translations: _parseBadgeTranslations(json['translations']),
    );
  }

  factory PassportBadge.fromCatalogJson(Map<String, dynamic> json) {
    return PassportBadge(
      id: _requiredString(json, 'id', maximumLength: 80, context: 'badge'),
      name: _requiredString(json, 'name', maximumLength: 80, context: 'badge'),
      description: _requiredString(
        json,
        'description',
        maximumLength: 240,
        context: 'badge',
      ),
      category: _requiredString(
        json,
        'category',
        maximumLength: 50,
        context: 'badge',
      ),
      collection: _requiredString(
        json,
        'collection',
        maximumLength: 80,
        context: 'badge',
      ),
      iconName: _catalogueIconForCategory(json['category'] as String),
      colourValue: _parseColour(json['accentColor']),
      target: _requiredInt(
        json,
        'target',
        minimum: 1,
        maximum: 50,
        context: 'badge',
      ),
      progress: 0,
      imageAsset: json['image'] is String ? json['image'] as String : null,
      sortOrder: json['sortOrder'] is int ? json['sortOrder'] as int : 0,
      rarity: json['rarity'] is String ? json['rarity'] as String : 'Common',
      translations: _parseBadgeTranslations(json['translations']),
    );
  }

  final String id;
  final String name;
  final String description;
  final String category;
  final String iconName;
  final int colourValue;
  final int target;
  final int progress;
  final String collection;
  final String? imageAsset;
  final int sortOrder;
  final String rarity;
  final Map<String, Map<String, String>> translations;

  String _localized(String languageCode, String field, String fallback) =>
      translations[languageCode]?[field]?.trim().isNotEmpty == true
      ? translations[languageCode]![field]!
      : fallback;

  String localizedName(String languageCode) =>
      _localized(languageCode, 'name', name);

  String localizedDescription(String languageCode) =>
      _localized(languageCode, 'description', description);

  String localizedCategory(String languageCode) =>
      _localized(languageCode, 'category', category);

  String localizedCollection(String languageCode) =>
      _localized(languageCode, 'collection', collection);

  String localizedRarity(String languageCode) =>
      _localized(languageCode, 'rarity', rarity);

  bool get earned => progress >= target;

  PassportBadge copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? iconName,
    int? colourValue,
    int? target,
    int? progress,
    String? collection,
    String? imageAsset,
    int? sortOrder,
    String? rarity,
    Map<String, Map<String, String>>? translations,
  }) {
    return PassportBadge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      iconName: iconName ?? this.iconName,
      colourValue: colourValue ?? this.colourValue,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      collection: collection ?? this.collection,
      imageAsset: imageAsset ?? this.imageAsset,
      sortOrder: sortOrder ?? this.sortOrder,
      rarity: rarity ?? this.rarity,
      translations: translations ?? this.translations,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'iconName': iconName,
      'colourValue': colourValue,
      'target': target,
      'progress': progress,
      'collection': collection,
      'imageAsset': imageAsset,
      'sortOrder': sortOrder,
      'rarity': rarity,
    };
  }
}

/// A successful, unique QR scan stored in the passport's activity history.
@immutable
class PassportScanRecord {
  const PassportScanRecord({
    required this.rewardId,
    required this.placeName,
    required this.xpAwarded,
    required this.scannedAt,
    this.badgeId,
    this.content,
    this.source = 'qr',
  });

  factory PassportScanRecord.fromJson(Map<String, dynamic> json) {
    final scannedAtSource = _requiredString(
      json,
      'scannedAt',
      maximumLength: 40,
      context: 'scan record',
    );
    final scannedAt = DateTime.tryParse(scannedAtSource);
    if (scannedAt == null) {
      throw const FormatException('scan record.scannedAt is not a valid date.');
    }

    final badgeIdSource = json['badgeId'];
    String? badgeId;
    if (badgeIdSource != null) {
      if (badgeIdSource is! String || badgeIdSource.trim().isEmpty) {
        throw const FormatException(
          'scan record.badgeId must be a non-empty string when supplied.',
        );
      }
      badgeId = badgeIdSource.trim();
      if (badgeId.length > 80) {
        throw const FormatException(
          'scan record.badgeId must be no more than 80 characters.',
        );
      }
    }

    PassportQrContent? content;
    final contentSource = json['content'];
    if (contentSource != null) {
      if (contentSource is! Map<String, dynamic>) {
        throw const FormatException(
          'scan record.content must be a JSON object.',
        );
      }
      content = PassportQrContent.fromJson(
        contentSource,
        context: 'scan record.content',
      );
    }

    final rewardId = _requiredString(
      json,
      'rewardId',
      maximumLength: 80,
      context: 'scan record',
    );
    final sourceValue = json['source'];
    final source = sourceValue is String && sourceValue.trim().isNotEmpty
        ? sourceValue.trim()
        : rewardId.startsWith('route-complete:') ||
              rewardId.startsWith('journey:')
        ? 'activity'
        : 'qr';

    return PassportScanRecord(
      rewardId: rewardId,
      placeName: _requiredString(
        json,
        'placeName',
        maximumLength: 100,
        context: 'scan record',
      ),
      xpAwarded: _requiredInt(
        json,
        'xpAwarded',
        minimum: 0,
        maximum: 500,
        context: 'scan record',
      ),
      badgeId: badgeId,
      scannedAt: scannedAt,
      content: content,
      source: source,
    );
  }

  final String rewardId;
  final String placeName;
  final int xpAwarded;
  final String? badgeId;
  final DateTime scannedAt;
  final PassportQrContent? content;
  final String source;

  bool get isQrScan => source == 'qr';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rewardId': rewardId,
      'placeName': placeName,
      'xpAwarded': xpAwarded,
      'badgeId': badgeId,
      'scannedAt': scannedAt.toUtc().toIso8601String(),
      'source': source,
      if (content != null) 'content': content!.toJson(),
    };
  }
}

/// The validated reward encoded directly in an Explore Canada Bay QR code.
@immutable
class PassportQrContent {
  const PassportQrContent({
    required this.title,
    required this.body,
    required this.category,
    this.officialUrl,
    this.localizationId,
    this.localizationArgs = const <String, String>{},
  });

  factory PassportQrContent.fromJson(
    Map<String, dynamic> json, {
    required String context,
  }) {
    final localizationIdSource = json['localizationId'];
    String? localizationId;
    if (localizationIdSource != null) {
      if (localizationIdSource is! String ||
          localizationIdSource.trim().isEmpty ||
          localizationIdSource.length > 120) {
        throw FormatException(
          '$context.localizationId must be non-empty text no longer than 120 characters.',
        );
      }
      localizationId = localizationIdSource.trim();
    }

    final localizationArgs = <String, String>{};
    final localizationArgsSource = json['localizationArgs'];
    if (localizationArgsSource != null) {
      if (localizationArgsSource is! Map) {
        throw FormatException('$context.localizationArgs must be an object.');
      }
      for (final entry in localizationArgsSource.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String ||
            key.trim().isEmpty ||
            key.length > 50 ||
            value is! String ||
            value.length > 700) {
          throw FormatException(
            '$context.localizationArgs must contain short text keys and values.',
          );
        }
        localizationArgs[key.trim()] = value;
      }
    }

    return PassportQrContent(
      title: _requiredString(
        json,
        'title',
        maximumLength: 100,
        context: context,
      ),
      body: _requiredString(json, 'body', maximumLength: 700, context: context),
      category: _requiredString(
        json,
        'category',
        maximumLength: 50,
        context: context,
      ),
      officialUrl: _optionalWebUrl(
        json,
        'officialUrl',
        maximumLength: 400,
        context: context,
      ),
      localizationId: localizationId,
      localizationArgs: Map<String, String>.unmodifiable(localizationArgs),
    );
  }

  final String title;
  final String body;
  final String category;
  final String? officialUrl;
  final String? localizationId;
  final Map<String, String> localizationArgs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'body': body,
      'category': category,
      if (officialUrl != null) 'officialUrl': officialUrl,
      if (localizationId != null) 'localizationId': localizationId,
      if (localizationArgs.isNotEmpty) 'localizationArgs': localizationArgs,
    };
  }
}

/// The validated reward encoded directly in an Explore Canada Bay QR code.
@immutable
class PassportQrReward {
  const PassportQrReward({
    required this.rewardId,
    required this.placeName,
    required this.xp,
    this.badge,
    this.badgeUnlock = false,
    this.content,
  });

  static const String namespace = 'explore_canada_bay.passport';
  static const int version = 1;

  final String rewardId;
  final String placeName;
  final int xp;
  final PassportBadge? badge;
  final PassportQrContent? content;

  /// Whether this scan immediately completes its badge.
  final bool badgeUnlock;

  String get place => placeName;
  int get xpAwarded => xp;

  static PassportQrReward parse(String raw) {
    if (raw.trim().isEmpty) {
      throw const FormatException('The QR code is empty.');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('The QR code does not contain valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The QR reward must be a JSON object.');
    }

    if (decoded['namespace'] != namespace) {
      throw const FormatException(
        'This QR code is not an Explore Canada Bay passport reward.',
      );
    }
    if (decoded['version'] != version) {
      throw const FormatException('This QR reward version is not supported.');
    }

    final rewardId = _requiredString(
      decoded,
      'rewardId',
      maximumLength: 80,
      context: 'reward',
    );
    final placeName = _requiredString(
      decoded,
      'place',
      maximumLength: 100,
      context: 'reward',
    );
    final xp = _requiredInt(
      decoded,
      'xp',
      minimum: 0,
      maximum: 500,
      context: 'reward',
    );

    PassportQrContent? content;
    final contentSource = decoded['content'];
    if (contentSource != null) {
      if (contentSource is! Map<String, dynamic>) {
        throw const FormatException('reward.content must be a JSON object.');
      }
      content = PassportQrContent.fromJson(
        contentSource,
        context: 'reward.content',
      );
    }

    final badgeSource = decoded['badge'];
    if (badgeSource == null) {
      return PassportQrReward(
        rewardId: rewardId,
        placeName: placeName,
        xp: xp,
        content: content,
      );
    }
    if (badgeSource is! Map<String, dynamic>) {
      throw const FormatException('reward.badge must be a JSON object.');
    }

    final target = _requiredInt(
      badgeSource,
      'target',
      minimum: 1,
      maximum: 50,
      context: 'reward.badge',
    );
    final suppliedProgress = _requiredInt(
      badgeSource,
      'progress',
      minimum: 1,
      maximum: target,
      context: 'reward.badge',
    );
    final unlockSource = badgeSource['unlock'];
    if (unlockSource != null && unlockSource is! bool) {
      throw const FormatException('reward.badge.unlock must be a boolean.');
    }
    final unlock = unlockSource as bool? ?? false;

    final badge = PassportBadge(
      id: _requiredString(
        badgeSource,
        'id',
        maximumLength: 80,
        context: 'reward.badge',
      ),
      name: _requiredString(
        badgeSource,
        'name',
        maximumLength: 80,
        context: 'reward.badge',
      ),
      description: _requiredString(
        badgeSource,
        'description',
        maximumLength: 240,
        context: 'reward.badge',
      ),
      category: _requiredString(
        badgeSource,
        'category',
        maximumLength: 50,
        context: 'reward.badge',
      ),
      iconName: _requiredString(
        badgeSource,
        'icon',
        maximumLength: 80,
        context: 'reward.badge',
      ),
      colourValue: _parseColour(badgeSource['color']),
      target: target,
      progress: unlock ? target : suppliedProgress,
    );

    return PassportQrReward(
      rewardId: rewardId,
      placeName: placeName,
      xp: xp,
      badge: badge,
      badgeUnlock: unlock,
      content: content,
    );
  }
}

/// The outcome of applying a parsed QR reward to a passport.
@immutable
class PassportRewardResult {
  const PassportRewardResult({
    required this.reward,
    required this.duplicate,
    required this.badgeJustEarned,
    required this.xpAwarded,
    required this.message,
    this.badge,
  });

  final PassportQrReward reward;
  final PassportBadge? badge;
  final bool duplicate;
  final bool badgeJustEarned;
  final int xpAwarded;
  final String message;
}

/// Minimal storage boundary so passport logic can be tested without plugins.
abstract interface class PassportStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class SharedPreferencesPassportStore implements PassportStore {
  SharedPreferencesPassportStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}

/// Owns passport progress and persists it as a single versioned JSON document.
class PassportController extends ChangeNotifier {
  PassportController({PassportStore? store, String ownerId = 'guest'})
    : _store = store ?? SharedPreferencesPassportStore(),
      _ownerId = _normaliseOwnerId(ownerId) {
    _resetToDefaults();
  }

  static const int baselineXp = 0;
  static const int xpPerLevel = 500;
  static const String debugUnlockAllCode = 'ECB-DEV-UNLOCK-ALL';
  static const String _storagePrefix = 'explore_canada_bay.passport.v2';
  static const int _storageVersion = 2;

  final PassportStore _store;
  String _ownerId;
  int _loadGeneration = 0;
  Future<void> _ownerLoad = Future<void>.value();
  final List<PassportBadge> _badges = <PassportBadge>[];
  final List<PassportScanRecord> _scanHistory = <PassportScanRecord>[];
  final List<String> _featuredBadgeIds = <String>[];

  int _totalXp = baselineXp;

  int get totalXp => _totalXp;

  int get todayXp {
    final now = DateTime.now();
    return _scanHistory
        .where((record) {
          final scannedAt = record.scannedAt.toLocal();
          return scannedAt.year == now.year &&
              scannedAt.month == now.month &&
              scannedAt.day == now.day;
        })
        .fold(0, (total, record) => total + record.xpAwarded);
  }

  List<PassportBadge> get badges => List<PassportBadge>.unmodifiable(_badges);

  List<PassportScanRecord> get scanHistory =>
      List<PassportScanRecord>.unmodifiable(_scanHistory);

  List<String> get featuredBadgeIds =>
      List<String>.unmodifiable(_featuredBadgeIds);
  String get ownerId => _ownerId;

  List<PassportBadge> get featuredBadges => _featuredBadgeIds
      .map(_badgeWithId)
      .whereType<PassportBadge>()
      .where((badge) => badge.earned)
      .toList(growable: false);

  int get earnedBadgeCount => _badges.where((badge) => badge.earned).length;
  int get totalScans => _scanHistory.where((record) => record.isQrScan).length;
  int get level => (_totalXp ~/ xpPerLevel) + 1;
  double get levelProgress => (_totalXp % xpPerLevel) / xpPerLevel;
  int get xpToNextLevel => xpPerLevel - (_totalXp % xpPerLevel);

  String get _storageKey => _storageKeyFor(_ownerId);

  String _storageKeyFor(String ownerId) => '$_storagePrefix.$ownerId';

  Future<void> switchOwner(String ownerId) async {
    final nextOwner = _normaliseOwnerId(ownerId);
    if (_ownerId == nextOwner) {
      await _ownerLoad;
      return;
    }
    _ownerId = nextOwner;
    _loadGeneration++;
    _resetToDefaults();
    notifyListeners();
    await load();
  }

  Future<void> load() {
    final generation = ++_loadGeneration;
    final ownerId = _ownerId;
    final operation = _loadOwner(generation: generation, ownerId: ownerId);
    _ownerLoad = operation;
    return operation;
  }

  Future<void> _loadOwner({
    required int generation,
    required String ownerId,
  }) async {
    List<PassportBadge> catalogue;
    try {
      catalogue = await _loadBadgeCatalogue();
    } on Object catch (error) {
      debugPrint('Badge catalogue could not be loaded: $error');
      catalogue = _defaultBadges();
    }

    String? source;
    try {
      source = await _store.read(_storageKeyFor(ownerId));
    } on Object catch (error) {
      debugPrint('Passport state could not be read: $error');
    }

    if (generation != _loadGeneration || ownerId != _ownerId) {
      return;
    }

    _resetToDefaults(catalogue);
    if (source != null) {
      try {
        _restore(source, catalogue);
      } on Object catch (error) {
        // A broken or stale save must never prevent the passport from opening.
        debugPrint('Passport state could not be restored: $error');
        _resetToDefaults(catalogue);
      }
    }

    notifyListeners();
  }

  Future<PassportRewardResult> applyQrPayload(String raw) async {
    await _ownerLoad;
    if (_badges.isEmpty) {
      await load();
    }

    if (kDebugMode && raw.trim() == debugUnlockAllCode) {
      return _unlockAllBadgesForDebug();
    }

    final reward = PassportQrReward.parse(raw);
    final existingRecord = _scanHistory.any(
      (record) => record.rewardId == reward.rewardId,
    );

    if (existingRecord) {
      final existingBadge = reward.badge == null
          ? null
          : _badgeWithId(reward.badge!.id);
      return PassportRewardResult(
        reward: reward,
        badge: existingBadge,
        duplicate: true,
        badgeJustEarned: false,
        xpAwarded: 0,
        message:
            '${reward.placeName} has already been scanned. No rewards were added.',
      );
    }

    PassportBadge? updatedBadge;
    var badgeJustEarned = false;
    final incomingBadge = reward.badge;

    if (incomingBadge != null) {
      final existingIndex = _badges.indexWhere(
        (badge) => badge.id == incomingBadge.id,
      );

      if (existingIndex == -1) {
        throw FormatException(
          'Badge "${incomingBadge.id}" is not in the trusted badge catalogue.',
        );
      }
      final currentBadge = _badges[existingIndex];
      final nextProgress = reward.badgeUnlock
          ? currentBadge.target
          : (currentBadge.progress + incomingBadge.progress).clamp(
              0,
              currentBadge.target,
            );
      updatedBadge = currentBadge.copyWith(progress: nextProgress);
      badgeJustEarned = !currentBadge.earned && updatedBadge.earned;
      _badges[existingIndex] = updatedBadge;
    }

    _totalXp += reward.xp;
    _scanHistory.insert(
      0,
      PassportScanRecord(
        rewardId: reward.rewardId,
        placeName: reward.placeName,
        xpAwarded: reward.xp,
        badgeId: updatedBadge?.id,
        scannedAt: DateTime.now().toUtc(),
        content: reward.content,
      ),
    );

    notifyListeners();
    await _persist();

    return PassportRewardResult(
      reward: reward,
      badge: updatedBadge,
      duplicate: false,
      badgeJustEarned: badgeJustEarned,
      xpAwarded: reward.xp,
      message: _successMessage(
        reward: reward,
        badge: updatedBadge,
        badgeJustEarned: badgeJustEarned,
      ),
    );
  }

  /// Records a trusted in-app civic activity using the same duplicate-safe
  /// reward pipeline as QR scans. This is used for route completion, event
  /// participation and other passport actions that do not require a QR code.
  Future<PassportRewardResult> recordActivity({
    required String activityId,
    required String placeName,
    required int points,
    String? badgeId,
    PassportQrContent? content,
  }) async {
    await _ownerLoad;
    if (_badges.isEmpty) {
      await load();
    }
    final badge = badgeId == null ? null : _badgeWithId(badgeId);
    final payload = <String, dynamic>{
      'namespace': PassportQrReward.namespace,
      'version': PassportQrReward.version,
      'rewardId': activityId,
      'place': placeName,
      'xp': points.clamp(0, 500),
      if (badge != null)
        'badge': <String, dynamic>{
          'id': badge.id,
          'name': badge.name,
          'description': badge.description,
          'category': badge.category,
          'icon': badge.iconName,
          'color': badge.colourValue,
          'target': badge.target,
          'progress': 1,
        },
      if (content != null) 'content': content.toJson(),
    };
    final result = await applyQrPayload(jsonEncode(payload));
    if (!result.duplicate) {
      final index = _scanHistory.indexWhere(
        (record) => record.rewardId == activityId,
      );
      if (index != -1) {
        final record = _scanHistory[index];
        _scanHistory[index] = PassportScanRecord(
          rewardId: record.rewardId,
          placeName: record.placeName,
          xpAwarded: record.xpAwarded,
          scannedAt: record.scannedAt,
          badgeId: record.badgeId,
          content: record.content,
          source: 'activity',
        );
        notifyListeners();
        await _persist();
      }
    }
    return result;
  }

  bool hasActivity(String activityId) =>
      _scanHistory.any((record) => record.rewardId == activityId);

  int badgeProgress(String badgeId) => _badgeWithId(badgeId)?.progress ?? 0;

  Future<void> toggleFeaturedBadge(String badgeId) async {
    await _ownerLoad;

    final badge = _badgeWithId(badgeId);
    if (badge == null || !badge.earned) return;

    if (_featuredBadgeIds.remove(badgeId)) {
      notifyListeners();
      await _persist();
      return;
    }
    if (_featuredBadgeIds.length >= 3) return;

    _featuredBadgeIds.add(badgeId);
    notifyListeners();
    await _persist();
  }

  Future<PassportRewardResult> _unlockAllBadgesForDebug() async {
    for (var index = 0; index < _badges.length; index++) {
      _badges[index] = _badges[index].copyWith(progress: _badges[index].target);
    }
    notifyListeners();
    await _persist();

    const reward = PassportQrReward(
      rewardId: 'debug-unlock-all',
      placeName: 'Developer tools',
      xp: 0,
    );
    return const PassportRewardResult(
      reward: reward,
      duplicate: false,
      badgeJustEarned: true,
      xpAwarded: 0,
      message: 'Developer reward applied: every badge is now unlocked.',
    );
  }

  void _restore(String source, List<PassportBadge> catalogue) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Passport state must be a JSON object.');
    }
    if (decoded['version'] != _storageVersion) {
      throw const FormatException('Unsupported passport state version.');
    }

    final totalXp = decoded['totalXp'];
    final badgesSource = decoded['badges'];
    final historySource = decoded['scanHistory'];
    final featuredSource = decoded['featuredBadgeIds'];
    if (totalXp is! int || totalXp < baselineXp) {
      throw const FormatException('Passport total XP is invalid.');
    }
    if (badgesSource is! List || historySource is! List) {
      throw const FormatException('Passport collections are invalid.');
    }

    final savedBadges = badgesSource.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('A saved passport badge is invalid.');
      }
      return PassportBadge.fromJson(item);
    }).toList();
    final savedHistory = historySource.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('A saved scan record is invalid.');
      }
      return PassportScanRecord.fromJson(item);
    }).toList();

    final rewardIds = <String>{};
    for (final record in savedHistory) {
      if (!rewardIds.add(record.rewardId)) {
        throw const FormatException('Passport scan history has duplicate IDs.');
      }
    }

    final canonicalBadges = List<PassportBadge>.of(catalogue);
    final canonicalById = <String, PassportBadge>{
      for (final badge in canonicalBadges) badge.id: badge,
    };
    final unknownBadges = <PassportBadge>[];
    final loadedBadgeIds = <String>{};

    for (final savedBadge in savedBadges) {
      if (!loadedBadgeIds.add(savedBadge.id)) {
        throw const FormatException('Passport badges contain duplicate IDs.');
      }

      final canonical = canonicalById[savedBadge.id];
      if (canonical == null) {
        unknownBadges.add(savedBadge);
        continue;
      }

      final canonicalIndex = canonicalBadges.indexWhere(
        (badge) => badge.id == canonical.id,
      );
      canonicalBadges[canonicalIndex] = canonical.copyWith(
        progress: savedBadge.progress.clamp(0, canonical.target),
      );
    }

    _totalXp = totalXp;
    _badges
      ..clear()
      ..addAll(canonicalBadges)
      ..addAll(unknownBadges);
    _scanHistory
      ..clear()
      ..addAll(savedHistory);
    _featuredBadgeIds
      ..clear()
      ..addAll(
        featuredSource is List
            ? featuredSource
                  .whereType<String>()
                  .where((id) => _badgeWithId(id)?.earned ?? false)
                  .take(3)
            : const <String>[],
      );
  }

  Future<void> _persist() async {
    final state = <String, dynamic>{
      'version': _storageVersion,
      'totalXp': _totalXp,
      'badges': _badges.map((badge) => badge.toJson()).toList(),
      'scanHistory': _scanHistory.map((record) => record.toJson()).toList(),
      'featuredBadgeIds': _featuredBadgeIds,
    };

    try {
      await _store.write(_storageKey, jsonEncode(state));
    } on Object catch (error) {
      // Keep the in-memory reward usable if device storage is unavailable.
      debugPrint('Passport state could not be saved: $error');
    }
  }

  PassportBadge? _badgeWithId(String id) {
    for (final badge in _badges) {
      if (badge.id == id) {
        return badge;
      }
    }
    return null;
  }

  void _resetToDefaults([List<PassportBadge>? catalogue]) {
    _totalXp = baselineXp;
    _badges
      ..clear()
      ..addAll(catalogue ?? const <PassportBadge>[]);
    _scanHistory.clear();
    _featuredBadgeIds.clear();
  }

  static Future<List<PassportBadge>> _loadBadgeCatalogue() async {
    final source = await rootBundle.loadString('assets/data/badges.json');
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('badges.json must contain a JSON list.');
    }

    final badges = decoded.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Every badge must be a JSON object.');
      }
      return PassportBadge.fromCatalogJson(item);
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final ids = <String>{};
    if (badges.any((badge) => !ids.add(badge.id))) {
      throw const FormatException('badges.json contains duplicate badge IDs.');
    }
    return badges;
  }

  static List<PassportBadge> _defaultBadges() {
    return const <PassportBadge>[
      PassportBadge(
        id: 'nature_trail',
        name: 'Nature Trail',
        description: 'Discover parks, wildlife and native habitats.',
        category: 'Nature',
        iconName: 'eco_rounded',
        colourValue: 0xFF00B87A,
        target: 5,
        progress: 0,
        collection: 'Outdoor Explorer',
        translations: {
          'zh': {
            'name': '自然步道',
            'description': '探索公园、野生动物和原生栖息地。',
            'category': '自然',
            'collection': '户外探索者',
            'rarity': '常见',
          },
          'ko': {
            'name': '자연 탐방로',
            'description': '공원, 야생동물 및 토착 서식지를 발견하세요.',
            'category': '자연',
            'collection': '야외 탐험가',
            'rarity': '일반',
          },
          'it': {
            'name': 'Sentiero natura',
            'description': 'Scopri parchi, fauna e habitat nativi.',
            'category': 'Natura',
            'collection': 'Esploratore all’aperto',
            'rarity': 'Comune',
          },
          'hi': {
            'name': 'प्रकृति पथ',
            'description': 'पार्क, वन्यजीव और स्थानीय आवास खोजें।',
            'category': 'प्रकृति',
            'collection': 'बाहरी खोजकर्ता',
            'rarity': 'सामान्य',
          },
        },
      ),
      PassportBadge(
        id: 'food_finder',
        name: 'Food Finder',
        description: 'Taste your way through Canada Bay favourites.',
        category: 'Food',
        iconName: 'restaurant_rounded',
        colourValue: 0xFFFFB74D,
        target: 5,
        progress: 0,
        collection: 'Local Life',
        translations: {
          'zh': {
            'name': '美食发现者',
            'description': '品尝加拿大湾人气美食。',
            'category': '美食',
            'collection': '本地生活',
            'rarity': '常见',
          },
          'ko': {
            'name': '맛집 탐험가',
            'description': '캐나다 베이의 인기 음식을 맛보세요.',
            'category': '음식',
            'collection': '지역 생활',
            'rarity': '일반',
          },
          'it': {
            'name': 'Cercatore di sapori',
            'description': 'Assaggia i sapori preferiti di Canada Bay.',
            'category': 'Cibo',
            'collection': 'Vita locale',
            'rarity': 'Comune',
          },
          'hi': {
            'name': 'भोजन खोजकर्ता',
            'description': 'कनाडा बे के पसंदीदा स्वाद चखें।',
            'category': 'भोजन',
            'collection': 'स्थानीय जीवन',
            'rarity': 'सामान्य',
          },
        },
      ),
      PassportBadge(
        id: 'heritage_hunter',
        name: 'Heritage Hunter',
        description: 'Uncover the stories behind local landmarks.',
        category: 'Heritage',
        iconName: 'account_balance_rounded',
        colourValue: 0xFF5FA8FF,
        target: 4,
        progress: 0,
        collection: 'Local Life',
        translations: {
          'zh': {
            'name': '历史探索者',
            'description': '发掘本地地标背后的故事。',
            'category': '历史文化',
            'collection': '本地生活',
            'rarity': '常见',
          },
          'ko': {
            'name': '유산 탐험가',
            'description': '지역 명소에 담긴 이야기를 발견하세요.',
            'category': '문화유산',
            'collection': '지역 생활',
            'rarity': '일반',
          },
          'it': {
            'name': 'Cacciatore di storia',
            'description': 'Scopri le storie dei monumenti locali.',
            'category': 'Patrimonio',
            'collection': 'Vita locale',
            'rarity': 'Comune',
          },
          'hi': {
            'name': 'विरासत खोजकर्ता',
            'description': 'स्थानीय स्थलों की कहानियाँ जानें।',
            'category': 'विरासत',
            'collection': 'स्थानीय जीवन',
            'rarity': 'सामान्य',
          },
        },
      ),
      PassportBadge(
        id: 'foreshore_walker',
        name: 'Foreshore Walker',
        description: 'Follow Canada Bay\'s waterside trails.',
        category: 'Walking',
        iconName: 'waves_rounded',
        colourValue: 0xFF64C8DC,
        target: 3,
        progress: 0,
        collection: 'Outdoor Explorer',
        translations: {
          'zh': {
            'name': '滨水步行者',
            'description': '沿着加拿大湾滨水步道前行。',
            'category': '步行',
            'collection': '户外探索者',
            'rarity': '常见',
          },
          'ko': {
            'name': '해안 산책가',
            'description': '캐나다 베이의 물가 산책로를 걸어보세요.',
            'category': '걷기',
            'collection': '야외 탐험가',
            'rarity': '일반',
          },
          'it': {
            'name': 'Camminatore sul litorale',
            'description': 'Segui i percorsi sull’acqua di Canada Bay.',
            'category': 'Camminata',
            'collection': 'Esploratore all’aperto',
            'rarity': 'Comune',
          },
          'hi': {
            'name': 'तट पथ यात्री',
            'description': 'कनाडा बे के पानी किनारे मार्गों पर चलें।',
            'category': 'पैदल यात्रा',
            'collection': 'बाहरी खोजकर्ता',
            'rarity': 'सामान्य',
          },
        },
      ),
    ];
  }

  static String _normaliseOwnerId(String value) {
    final cleaned = value.trim().toLowerCase();
    if (cleaned.isEmpty) return 'guest';
    return base64Url.encode(utf8.encode(cleaned)).replaceAll('=', '');
  }

  static String _successMessage({
    required PassportQrReward reward,
    required PassportBadge? badge,
    required bool badgeJustEarned,
  }) {
    final xpMessage = reward.xp == 0 ? '' : '+${reward.xp} XP';

    if (badgeJustEarned && badge != null) {
      return xpMessage.isEmpty
          ? '${badge.name} badge unlocked!'
          : '${badge.name} badge unlocked! $xpMessage';
    }
    if (badge != null) {
      final progressMessage =
          '${badge.progress}/${badge.target} badge progress';
      return xpMessage.isEmpty
          ? '${reward.placeName}: $progressMessage.'
          : '$xpMessage and $progressMessage at ${reward.placeName}.';
    }
    if (xpMessage.isNotEmpty) {
      return '$xpMessage earned at ${reward.placeName}.';
    }
    return '${reward.placeName} added to your passport.';
  }
}

Map<String, Map<String, String>> _parseBadgeTranslations(dynamic source) {
  if (source is! Map) return const <String, Map<String, String>>{};
  final translations = <String, Map<String, String>>{};
  for (final languageEntry in source.entries) {
    final fieldsSource = languageEntry.value;
    if (fieldsSource is! Map) continue;
    final fields = <String, String>{};
    for (final fieldEntry in fieldsSource.entries) {
      final value = fieldEntry.value;
      if (value is String && value.trim().isNotEmpty) {
        fields[fieldEntry.key.toString()] = value.trim();
      }
    }
    if (fields.isNotEmpty) {
      translations[languageEntry.key.toString()] = Map.unmodifiable(fields);
    }
  }
  return Map.unmodifiable(translations);
}

String _catalogueIconForCategory(String category) {
  switch (category.trim().toLowerCase()) {
    case 'nature':
      return 'eco_rounded';
    case 'food':
      return 'restaurant_rounded';
    case 'heritage':
      return 'account_balance_rounded';
    case 'walking':
      return 'waves_rounded';
    case 'library':
      return 'local_library_rounded';
    case 'community':
      return 'groups_rounded';
    case 'volunteer':
      return 'volunteer_activism_rounded';
    case 'business':
      return 'storefront_rounded';
    case 'art':
      return 'palette_rounded';
    case 'civic':
      return 'account_balance_rounded';
    default:
      return 'workspace_premium_rounded';
  }
}

String _requiredString(
  Map<String, dynamic> json,
  String key, {
  required int maximumLength,
  required String context,
}) {
  final source = json[key];
  if (source is! String || source.trim().isEmpty) {
    throw FormatException('$context.$key must be a non-empty string.');
  }

  final value = source.trim();
  if (value.length > maximumLength) {
    throw FormatException(
      '$context.$key must be no more than $maximumLength characters.',
    );
  }
  return value;
}

String? _optionalString(
  Map<String, dynamic> json,
  String key, {
  required int maximumLength,
  required String context,
}) {
  final source = json[key];
  if (source == null) return null;
  if (source is! String) {
    throw FormatException('$context.$key must be a string when supplied.');
  }
  final value = source.trim();
  if (value.isEmpty) return null;
  if (value.length > maximumLength) {
    throw FormatException(
      '$context.$key must be no more than $maximumLength characters.',
    );
  }
  return value;
}

String? _optionalWebUrl(
  Map<String, dynamic> json,
  String key, {
  required int maximumLength,
  required String context,
}) {
  final value = _optionalString(
    json,
    key,
    maximumLength: maximumLength,
    context: context,
  );
  if (value == null) return null;

  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw FormatException('$context.$key must be an HTTP or HTTPS URL.');
  }
  return value;
}

int _requiredInt(
  Map<String, dynamic> json,
  String key, {
  required int minimum,
  required int maximum,
  required String context,
}) {
  final value = json[key];
  if (value is! int || value < minimum || value > maximum) {
    throw FormatException(
      '$context.$key must be an integer from $minimum to $maximum.',
    );
  }
  return value;
}

int _parseColour(Object? source) {
  if (source is int && source >= 0 && source <= 0xFFFFFFFF) {
    return source;
  }

  if (source is String) {
    final value = source.trim();
    final match = RegExp(
      r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
    ).firstMatch(value);
    if (match != null) {
      final digits = match.group(1)!;
      final argb = digits.length == 6 ? 'FF$digits' : digits;
      return int.parse(argb, radix: 16);
    }
  }

  throw const FormatException(
    'reward.badge.color must be an ARGB integer or a 6/8 digit hex colour.',
  );
}
