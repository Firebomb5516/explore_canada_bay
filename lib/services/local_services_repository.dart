import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/local_service_item.dart';

typedef LocalServicesAssetLoader = Future<String> Function(String assetPath);

/// Reads and validates the bundled civic-services catalogue.
class LocalServicesRepository {
  const LocalServicesRepository({this.assetLoader});

  static const assetPath = 'assets/data/local_services.json';

  final LocalServicesAssetLoader? assetLoader;

  Future<LocalServicesCatalog> loadCatalog() async {
    final rawJson =
        await (assetLoader?.call(assetPath) ??
            rootBundle.loadString(assetPath));

    final dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (error) {
      throw LocalServicesRepositoryException(
        'Local services data is not valid JSON.',
        cause: error,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const LocalServicesRepositoryException(
        'Local services data must use a JSON object at its root.',
      );
    }

    try {
      return LocalServicesCatalog.fromJson(decoded);
    } on FormatException catch (error) {
      throw LocalServicesRepositoryException(
        'Local services data failed validation: ${error.message}',
        cause: error,
      );
    }
  }
}

class LocalServicesRepositoryException implements Exception {
  const LocalServicesRepositoryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
