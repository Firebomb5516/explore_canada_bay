import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/environmental_story.dart';

class EnvironmentRepository {
  const EnvironmentRepository();

  Future<List<EnvironmentalStory>> loadStories({
    Locale locale = const Locale('en'),
  }) async {
    final source = await rootBundle.loadString('assets/data/environment.json');
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('environment.json must contain a JSON list.');
    }

    final stories = decoded
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException(
              'Every environmental story must be a JSON object.',
            );
          }
          return EnvironmentalStory.fromJson(item).localized(locale);
        })
        .toList(growable: false);

    final ids = <String>{};
    if (stories.any((story) => !ids.add(story.id))) {
      throw const FormatException(
        'environment.json contains duplicate story IDs.',
      );
    }
    return stories;
  }
}
