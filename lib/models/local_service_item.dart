/// Categories used to organise practical information for new Canada Bay
/// residents.
enum LocalServiceCategory {
  waste,
  parks,
  libraries,
  transport,
  parking,
  amenities,
  emergency,
  council,
  pets;

  String get label => switch (this) {
    LocalServiceCategory.waste => 'Waste & recycling',
    LocalServiceCategory.parks => 'Parks & BBQs',
    LocalServiceCategory.libraries => 'Libraries',
    LocalServiceCategory.transport => 'Transport',
    LocalServiceCategory.parking => 'Parking',
    LocalServiceCategory.amenities => 'Public amenities',
    LocalServiceCategory.emergency => 'Emergency',
    LocalServiceCategory.council => 'Council help',
    LocalServiceCategory.pets => 'Dog parks',
  };

  static LocalServiceCategory parse(String value) {
    return LocalServiceCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () =>
          throw FormatException('Unknown local service category "$value".'),
    );
  }
}

/// Trusted civic information presented in the Local Services directory.
class LocalServiceItem {
  static const requiredTranslationLanguageCodes = <String>{
    'zh',
    'ko',
    'it',
    'hi',
  };

  const LocalServiceItem({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.details,
    required this.actionLabel,
    required this.sourceLabel,
    required this.officialUrl,
    required this.highlights,
    required this.keywords,
    required this.isEssential,
    required this.isEmergency,
    required this.sortOrder,
    this.phone,
    this.translations = const {},
  });

  final String id;
  final String title;
  final LocalServiceCategory category;
  final String summary;
  final String details;
  final String actionLabel;
  final String sourceLabel;
  final String officialUrl;
  final List<String> highlights;
  final List<String> keywords;
  final bool isEssential;
  final bool isEmergency;
  final int sortOrder;
  final String? phone;
  final Map<String, LocalServiceItemTranslation> translations;

  factory LocalServiceItem.fromJson(Map<String, dynamic> json) {
    final officialUrl = _requiredString(json, 'officialUrl');
    final uri = Uri.tryParse(officialUrl);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      throw FormatException(
        'Local service "${json['id']}" must use a valid HTTPS officialUrl.',
      );
    }

    final isEmergency = _requiredBool(json, 'isEmergency');
    final phone = _optionalString(json, 'phone');
    if (isEmergency && phone != '000') {
      throw FormatException(
        'Emergency service "${json['id']}" must identify Triple Zero (000).',
      );
    }

    return LocalServiceItem(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      category: LocalServiceCategory.parse(_requiredString(json, 'category')),
      summary: _requiredString(json, 'summary'),
      details: _requiredString(json, 'details'),
      actionLabel: _requiredString(json, 'actionLabel'),
      sourceLabel: _requiredString(json, 'sourceLabel'),
      officialUrl: officialUrl,
      highlights: _requiredStringList(json, 'highlights'),
      keywords: _requiredStringList(json, 'keywords'),
      isEssential: _requiredBool(json, 'isEssential'),
      isEmergency: isEmergency,
      sortOrder: _requiredInt(json, 'sortOrder'),
      phone: phone,
      translations: _parseServiceTranslations(
        json['translations'],
        json['id'],
        fallbackSourceLabel: _requiredString(json, 'sourceLabel'),
      ),
    );
  }

  /// Matches user-facing content and supporting discovery keywords.
  bool matches(String query, {String languageCode = 'en'}) {
    final normalised = query.trim().toLowerCase();
    if (normalised.isEmpty) return true;

    final searchable = <String>[
      title,
      category.label,
      summary,
      details,
      sourceLabel,
      ...highlights,
      ...keywords,
    ];
    final localized = translations[languageCode];
    if (localized != null) {
      searchable.addAll([
        localized.title,
        localized.summary,
        localized.details,
        localized.actionLabel,
        localized.sourceLabel,
        ...localized.highlights,
        ...localized.keywords,
      ]);
    }
    return searchable.any((value) => value.toLowerCase().contains(normalised));
  }

  /// Returns content for [languageCode], with English fallback for lightweight
  /// injected fixtures that predate localized catalogue data.
  LocalServiceItem localized(String languageCode) {
    final content = translations[languageCode];
    if (content == null) return this;
    return LocalServiceItem(
      id: id,
      title: content.title,
      category: category,
      summary: content.summary,
      details: content.details,
      actionLabel: content.actionLabel,
      sourceLabel: content.sourceLabel,
      officialUrl: officialUrl,
      highlights: content.highlights,
      keywords: content.keywords,
      isEssential: isEssential,
      isEmergency: isEmergency,
      sortOrder: sortOrder,
      phone: phone,
      translations: translations,
    );
  }

  bool hasCompleteTranslation(String languageCode) =>
      translations.containsKey(languageCode);
}

class LocalServiceItemTranslation {
  const LocalServiceItemTranslation({
    required this.title,
    required this.summary,
    required this.details,
    required this.actionLabel,
    required this.sourceLabel,
    required this.highlights,
    required this.keywords,
  });

  factory LocalServiceItemTranslation.fromJson(
    Map<String, dynamic> json, {
    required String itemId,
    required String languageCode,
    required String fallbackSourceLabel,
  }) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException(
          'Local service "$itemId" translation "$languageCode" is missing "$key".',
        );
      }
      return value.trim();
    }

    List<String> requiredList(String key) {
      final value = json[key];
      if (value is! List || value.isEmpty) {
        throw FormatException(
          'Local service "$itemId" translation "$languageCode" must have "$key".',
        );
      }
      return List.unmodifiable(
        value.map((entry) {
          if (entry is! String || entry.trim().isEmpty) {
            throw FormatException(
              'Local service "$itemId" translation "$languageCode" has invalid "$key" text.',
            );
          }
          return entry.trim();
        }),
      );
    }

    return LocalServiceItemTranslation(
      title: requiredText('title'),
      summary: requiredText('summary'),
      details: requiredText('details'),
      actionLabel: requiredText('actionLabel'),
      sourceLabel: json['sourceLabel'] == null
          ? fallbackSourceLabel
          : requiredText('sourceLabel'),
      highlights: requiredList('highlights'),
      keywords: requiredList('keywords'),
    );
  }

  final String title;
  final String summary;
  final String details;
  final String actionLabel;
  final String sourceLabel;
  final List<String> highlights;
  final List<String> keywords;
}

/// Versioned wrapper for the local services catalogue.
class LocalServicesCatalog {
  const LocalServicesCatalog({
    required this.schemaVersion,
    required this.lastReviewed,
    required this.services,
  });

  final int schemaVersion;
  final DateTime lastReviewed;
  final List<LocalServiceItem> services;

  factory LocalServicesCatalog.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported local services schema version $schemaVersion.',
      );
    }

    final lastReviewedValue = _requiredString(json, 'lastReviewed');
    final lastReviewed = DateTime.tryParse(lastReviewedValue);
    if (lastReviewed == null) {
      throw const FormatException(
        'Local services lastReviewed must be an ISO date.',
      );
    }

    final rawServices = json['services'];
    if (rawServices is! List || rawServices.isEmpty) {
      throw const FormatException(
        'Local services catalogue must contain services.',
      );
    }

    final services =
        rawServices.map((rawItem) {
          if (rawItem is! Map<String, dynamic>) {
            throw const FormatException(
              'Every local service must be a JSON object.',
            );
          }
          return LocalServiceItem.fromJson(rawItem);
        }).toList()..sort((a, b) {
          final order = a.sortOrder.compareTo(b.sortOrder);
          return order != 0 ? order : a.title.compareTo(b.title);
        });

    final ids = <String>{};
    for (final service in services) {
      if (!ids.add(service.id)) {
        throw FormatException('Duplicate local service id "${service.id}".');
      }
    }

    final emergencyServices = services.where((item) => item.isEmergency);
    if (emergencyServices.length != 1) {
      throw const FormatException(
        'Local services must contain exactly one emergency guidance item.',
      );
    }

    return LocalServicesCatalog(
      schemaVersion: schemaVersion,
      lastReviewed: lastReviewed,
      services: List.unmodifiable(services),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Local service field "$key" must be text.');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Local service field "$key" must be text.');
  }
  return value.trim();
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Local service field "$key" must be a boolean.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Local service field "$key" must be an integer.');
  }
  return value;
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.isEmpty) {
    throw FormatException(
      'Local service field "$key" must be a non-empty list.',
    );
  }

  return List.unmodifiable(
    value.map((entry) {
      if (entry is! String || entry.trim().isEmpty) {
        throw FormatException(
          'Local service field "$key" must contain only text.',
        );
      }
      return entry.trim();
    }),
  );
}

Map<String, LocalServiceItemTranslation> _parseServiceTranslations(
  Object? value,
  Object? itemId, {
  required String fallbackSourceLabel,
}) {
  if (value == null) return const {};
  if (value is! Map) {
    throw FormatException(
      'Local service "$itemId" must have a translations object.',
    );
  }

  final parsed = <String, LocalServiceItemTranslation>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! Map) {
      throw FormatException(
        'Local service "$itemId" has an invalid translation.',
      );
    }
    final languageCode = entry.key as String;
    if (!LocalServiceItem.requiredTranslationLanguageCodes.contains(
      languageCode,
    )) {
      throw FormatException(
        'Local service "$itemId" has unsupported translation "$languageCode".',
      );
    }
    parsed[languageCode] = LocalServiceItemTranslation.fromJson(
      Map<String, dynamic>.from(entry.value as Map),
      itemId: '$itemId',
      languageCode: languageCode,
      fallbackSourceLabel: fallbackSourceLabel,
    );
  }
  return Map.unmodifiable(parsed);
}
