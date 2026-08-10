import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/community_item.dart';

/// Loads and validates the curated Community catalogue from bundled JSON.
class CommunityRepository {
  const CommunityRepository({this.bundle, this.assetPath = defaultAssetPath});

  static const String defaultAssetPath = 'assets/data/community.json';

  final AssetBundle? bundle;
  final String assetPath;

  Future<List<CommunityItem>> load() async {
    final rawJson = await (bundle ?? rootBundle).loadString(assetPath);
    return parse(rawJson);
  }

  /// Public for deterministic catalogue and repository tests.
  List<CommunityItem> parse(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw const FormatException(
        'The community catalogue must be a JSON list.',
      );
    }

    final items = <CommunityItem>[];
    final seenIds = <String>{};
    for (var index = 0; index < decoded.length; index++) {
      final value = decoded[index];
      if (value is! Map) {
        throw FormatException(
          'Community catalogue entry $index must be an object.',
        );
      }
      final item = CommunityItem.fromJson(Map<String, dynamic>.from(value));
      if (!seenIds.add(item.id.toLowerCase())) {
        throw FormatException('Duplicate community item id "${item.id}".');
      }
      items.add(item);
    }

    items.sort((first, second) {
      final order = first.sortOrder.compareTo(second.sortOrder);
      return order != 0 ? order : first.title.compareTo(second.title);
    });
    return List.unmodifiable(items);
  }
}
