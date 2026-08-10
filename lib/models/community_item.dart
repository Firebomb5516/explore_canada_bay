/// Curated categories required by the Community section of the product brief.
enum CommunityCategory {
  events,
  library,
  sport,
  walking,
  cycling,
  volunteering,
  bushcare,
  festivals,
  markets,
  organisations;

  String get label => switch (this) {
    CommunityCategory.events => 'Events',
    CommunityCategory.library => 'Library',
    CommunityCategory.sport => 'Sport',
    CommunityCategory.walking => 'Walking',
    CommunityCategory.cycling => 'Cycling',
    CommunityCategory.volunteering => 'Volunteer',
    CommunityCategory.bushcare => 'Bushcare',
    CommunityCategory.festivals => 'Festivals',
    CommunityCategory.markets => 'Markets',
    CommunityCategory.organisations => 'Groups',
  };

  static CommunityCategory parse(String value) {
    final normalised = value.trim().toLowerCase();
    return CommunityCategory.values.firstWhere(
      (category) => category.name == normalised,
      orElse: () =>
          throw FormatException('Unknown community category "$value".'),
    );
  }
}

/// A trusted community opportunity loaded from the local JSON catalogue.
class CommunityItem {
  static const requiredTranslationLanguageCodes = <String>{
    'zh',
    'ko',
    'it',
    'hi',
  };

  const CommunityItem({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.details,
    required this.location,
    required this.schedule,
    required this.cost,
    required this.audience,
    required this.sourceLabel,
    required this.officialUrl,
    required this.actionLabel,
    required this.featured,
    required this.verifiedOn,
    required this.tags,
    required this.sortOrder,
    this.translations = const {},
  });

  factory CommunityItem.fromJson(Map<String, dynamic> json) {
    final officialUrl = _requiredString(json, 'officialUrl');
    final uri = Uri.tryParse(officialUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw FormatException(
        'Community item "${json['id']}" has an invalid officialUrl.',
      );
    }

    final verifiedOnValue = _requiredString(json, 'verifiedOn');
    final verifiedOn = DateTime.tryParse(verifiedOnValue);
    if (verifiedOn == null ||
        verifiedOnValue.length != 10 ||
        verifiedOnValue[4] != '-' ||
        verifiedOnValue[7] != '-') {
      throw FormatException(
        'Community item "${json['id']}" has an invalid verifiedOn date.',
      );
    }

    final featuredValue = json['featured'];
    if (featuredValue is! bool) {
      throw FormatException(
        'Community item "${json['id']}" must have a boolean featured value.',
      );
    }

    final sortOrderValue = json['sortOrder'];
    if (sortOrderValue is! int || sortOrderValue < 0) {
      throw FormatException(
        'Community item "${json['id']}" must have a non-negative sortOrder.',
      );
    }

    final tagsValue = json['tags'];
    if (tagsValue is! List) {
      throw FormatException(
        'Community item "${json['id']}" must have a tags list.',
      );
    }
    final tags = tagsValue
        .map((value) {
          if (value is! String || value.trim().isEmpty) {
            throw FormatException(
              'Community item "${json['id']}" has an invalid tag.',
            );
          }
          return value.trim();
        })
        .toList(growable: false);

    final translations = _parseTranslations(
      json['translations'],
      json['id'],
      fallbackSourceLabel: _requiredString(json, 'sourceLabel'),
    );

    return CommunityItem(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      category: CommunityCategory.parse(_requiredString(json, 'category')),
      summary: _requiredString(json, 'summary'),
      details: _requiredString(json, 'details'),
      location: _requiredString(json, 'location'),
      schedule: _requiredString(json, 'schedule'),
      cost: _requiredString(json, 'cost'),
      audience: _requiredString(json, 'audience'),
      sourceLabel: _requiredString(json, 'sourceLabel'),
      officialUrl: officialUrl,
      actionLabel: _requiredString(json, 'actionLabel'),
      featured: featuredValue,
      verifiedOn: DateTime.utc(
        verifiedOn.year,
        verifiedOn.month,
        verifiedOn.day,
      ),
      tags: List.unmodifiable(tags),
      sortOrder: sortOrderValue,
      translations: translations,
    );
  }

  final String id;
  final String title;
  final CommunityCategory category;
  final String summary;
  final String details;
  final String location;
  final String schedule;
  final String cost;
  final String audience;
  final String sourceLabel;
  final String officialUrl;
  final String actionLabel;
  final bool featured;
  final DateTime verifiedOn;
  final List<String> tags;
  final int sortOrder;
  final Map<String, CommunityItemTranslation> translations;

  Uri get officialUri => Uri.parse(officialUrl);

  /// Case-insensitive matching across the user-facing discovery fields.
  bool matches(String query, {String languageCode = 'en'}) {
    final normalised = query.trim().toLowerCase();
    if (normalised.isEmpty) {
      return true;
    }

    final searchable = <String>[
      title,
      category.label,
      summary,
      details,
      location,
      schedule,
      audience,
      sourceLabel,
      ...tags,
    ];

    final localized = translations[languageCode];
    if (localized != null) {
      searchable.addAll([
        localized.title,
        localized.summary,
        localized.details,
        localized.location,
        localized.schedule,
        localized.cost,
        localized.audience,
        localized.sourceLabel,
        localized.actionLabel,
        ...localized.tags,
      ]);
    }

    return searchable.join(' ').toLowerCase().contains(normalised);
  }

  /// Returns a display-ready copy for [languageCode], falling back to the
  /// canonical English item when an injected fixture has no translations.
  CommunityItem localized(String languageCode) {
    final content = translations[languageCode];
    if (content == null) return this;
    return CommunityItem(
      id: id,
      title: content.title,
      category: category,
      summary: content.summary,
      details: content.details,
      location: content.location,
      schedule: content.schedule,
      cost: content.cost,
      audience: content.audience,
      sourceLabel: content.sourceLabel,
      officialUrl: officialUrl,
      actionLabel: content.actionLabel,
      featured: featured,
      verifiedOn: verifiedOn,
      tags: content.tags,
      sortOrder: sortOrder,
      translations: translations,
    );
  }

  bool hasCompleteTranslation(String languageCode) =>
      translations.containsKey(languageCode);

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'Community item "${json['id']}" is missing "$key".',
      );
    }
    return value.trim();
  }

  static Map<String, CommunityItemTranslation> _parseTranslations(
    Object? value,
    Object? itemId, {
    required String fallbackSourceLabel,
  }) {
    if (value == null) return const {};
    if (value is! Map) {
      throw FormatException(
        'Community item "$itemId" must have a translations object.',
      );
    }

    final parsed = <String, CommunityItemTranslation>{};
    for (final entry in value.entries) {
      final languageCode = entry.key;
      if (languageCode is! String || entry.value is! Map) {
        throw FormatException(
          'Community item "$itemId" has an invalid translation.',
        );
      }
      if (!requiredTranslationLanguageCodes.contains(languageCode)) {
        throw FormatException(
          'Community item "$itemId" has unsupported translation "$languageCode".',
        );
      }
      parsed[languageCode] = CommunityItemTranslation.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
        itemId: '$itemId',
        languageCode: languageCode,
        fallbackSourceLabel: fallbackSourceLabel,
      );
    }
    return Map.unmodifiable(parsed);
  }
}

class CommunityItemTranslation {
  const CommunityItemTranslation({
    required this.title,
    required this.summary,
    required this.details,
    required this.location,
    required this.schedule,
    required this.cost,
    required this.audience,
    required this.sourceLabel,
    required this.actionLabel,
    required this.tags,
  });

  factory CommunityItemTranslation.fromJson(
    Map<String, dynamic> json, {
    required String itemId,
    required String languageCode,
    required String fallbackSourceLabel,
  }) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException(
          'Community item "$itemId" translation "$languageCode" is missing "$key".',
        );
      }
      return value.trim();
    }

    final rawTags = json['tags'];
    if (rawTags is! List || rawTags.isEmpty) {
      throw FormatException(
        'Community item "$itemId" translation "$languageCode" must have tags.',
      );
    }
    final tags = rawTags
        .map((tag) {
          if (tag is! String || tag.trim().isEmpty) {
            throw FormatException(
              'Community item "$itemId" translation "$languageCode" has an invalid tag.',
            );
          }
          return tag.trim();
        })
        .toList(growable: false);

    return CommunityItemTranslation(
      title: requiredText('title'),
      summary: requiredText('summary'),
      details: requiredText('details'),
      location: requiredText('location'),
      schedule: requiredText('schedule'),
      cost: requiredText('cost'),
      audience: requiredText('audience'),
      sourceLabel: json['sourceLabel'] == null
          ? fallbackSourceLabel
          : requiredText('sourceLabel'),
      actionLabel: requiredText('actionLabel'),
      tags: List.unmodifiable(tags),
    );
  }

  final String title;
  final String summary;
  final String details;
  final String location;
  final String schedule;
  final String cost;
  final String audience;
  final String sourceLabel;
  final String actionLabel;
  final List<String> tags;
}
