import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/newcomer_journey.dart';

typedef JourneyAssetLoader = Future<String> Function(String assetPath);

class NewcomerJourneyRepository {
  const NewcomerJourneyRepository({this.assetLoader});

  static const assetPath = 'assets/data/newcomer_journey.json';

  final JourneyAssetLoader? assetLoader;

  Future<NewcomerJourneyCatalog> loadCatalog() async {
    final source =
        await (assetLoader?.call(assetPath) ??
            rootBundle.loadString(assetPath));
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw JourneyRepositoryException(
        'Newcomer journey data is not valid JSON.',
        cause: error,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const JourneyRepositoryException(
        'Newcomer journey data must use an object at its root.',
      );
    }
    try {
      return NewcomerJourneyCatalog.fromJson(decoded);
    } on FormatException catch (error) {
      throw JourneyRepositoryException(
        'Newcomer journey data failed validation: ${error.message}',
        cause: error,
      );
    }
  }
}

class JourneyRepositoryException implements Exception {
  const JourneyRepositoryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
