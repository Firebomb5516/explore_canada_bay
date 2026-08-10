import 'package:flutter/widgets.dart';

@immutable
class EnvironmentalStory {
  const EnvironmentalStory({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.learningPrompt,
    required this.latitude,
    required this.longitude,
    required this.officialUrl,
    required this.sourceLabel,
    this.translations = const <String, Map<String, dynamic>>{},
  });

  factory EnvironmentalStory.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('environment.$key must be a non-empty string.');
      }
      return value.trim();
    }

    final latitude = json['lat'];
    final longitude = json['lng'];
    if (latitude is! num || longitude is! num) {
      throw const FormatException(
        'Environmental stories require numeric coordinates.',
      );
    }

    final rawTranslations = json['translations'];
    final translations = <String, Map<String, dynamic>>{};
    if (rawTranslations is Map) {
      for (final entry in rawTranslations.entries) {
        if (entry.value is Map) {
          translations[entry.key.toString()] = Map<String, dynamic>.from(
            entry.value as Map,
          );
        }
      }
    }

    return EnvironmentalStory(
      id: requiredText('id'),
      name: requiredText('name'),
      category: requiredText('category'),
      description: requiredText('description'),
      learningPrompt: requiredText('learningPrompt'),
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      officialUrl: requiredText('officialUrl'),
      sourceLabel: requiredText('sourceLabel'),
      translations: Map<String, Map<String, dynamic>>.unmodifiable(
        translations,
      ),
    );
  }

  EnvironmentalStory localized(Locale locale) {
    final translated = translations[locale.languageCode];
    if (translated == null) return this;

    String value(String key, String fallback) {
      final candidate = translated[key];
      return candidate is String && candidate.trim().isNotEmpty
          ? candidate.trim()
          : fallback;
    }

    return EnvironmentalStory(
      id: id,
      name: value('name', name),
      category: value('category', category),
      description: value('description', description),
      learningPrompt: value('learningPrompt', learningPrompt),
      latitude: latitude,
      longitude: longitude,
      officialUrl: officialUrl,
      sourceLabel: value('sourceLabel', sourceLabel),
      translations: translations,
    );
  }

  final String id;
  final String name;
  final String category;
  final String description;
  final String learningPrompt;
  final double latitude;
  final double longitude;
  final String officialUrl;
  final String sourceLabel;
  final Map<String, Map<String, dynamic>> translations;
}
