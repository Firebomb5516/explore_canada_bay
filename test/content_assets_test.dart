import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _minimumLocalLatitude = -33.91;
const _maximumLocalLatitude = -33.80;
const _minimumLocalLongitude = 151.06;
const _maximumLocalLongitude = 151.18;

void main() {
  group('bundled content integrity', () {
    test('every data JSON file parses', () {
      final dataDirectory = Directory('assets/data');
      expect(
        dataDirectory.existsSync(),
        isTrue,
        reason: 'The assets/data directory must exist.',
      );

      final jsonFiles =
          dataDirectory
              .listSync()
              .whereType<File>()
              .where((file) => file.path.toLowerCase().endsWith('.json'))
              .toList()
            ..sort((first, second) => first.path.compareTo(second.path));

      expect(
        jsonFiles,
        isNotEmpty,
        reason: 'At least one JSON data catalogue is required.',
      );

      for (final file in jsonFiles) {
        expect(
          () => jsonDecode(file.readAsStringSync()),
          returnsNormally,
          reason: '${file.path} must contain valid JSON.',
        );
      }
    });

    test('route and badge identifiers are present and unique', () {
      final routes = _readJsonList('assets/data/routes.json');
      final badges = _readJsonList('assets/data/badges.json');

      _expectUniqueRequiredStrings(routes, 'id', 'route');
      _expectUniqueRequiredStrings(badges, 'id', 'badge');

      for (final route in routes) {
        _expectRequiredString(route, 'title', 'route');
        _expectRequiredString(route, 'category', 'route');
        _expectRequiredString(route, 'gpx', 'route');
        _expectRequiredString(route, 'image', 'route');
        _expectLocalCoordinates(route, route['title'].toString());
      }

      for (final badge in badges) {
        final badgeName = _expectRequiredString(badge, 'name', 'badge');
        _expectRequiredString(badge, 'description', badgeName);
        _expectRequiredString(badge, 'category', badgeName);
        _expectRequiredString(badge, 'collection', badgeName);
        _expectRequiredString(badge, 'rarity', badgeName);
        _expectRequiredString(badge, 'accentColor', badgeName);
        expect(
          badge.containsKey('image'),
          isTrue,
          reason: '$badgeName must retain the badge image key.',
        );
        expect(
          badge['target'],
          isA<int>().having((value) => value, 'value', greaterThan(0)),
          reason: '$badgeName must have a positive target.',
        );
      }
    });

    test('place catalogues contain usable local coordinates', () {
      for (final path in const [
        'assets/data/locations.json',
        'assets/data/food.json',
        'assets/data/biodiversity.json',
      ]) {
        final places = _readJsonList(path);
        expect(places, isNotEmpty, reason: '$path must not be empty.');

        for (final place in places) {
          final name = _expectRequiredString(place, 'name', path);
          _expectRequiredString(place, 'type', name);
          _expectLocalCoordinates(place, name);
        }
      }
    });

    test('every non-empty referenced asset exists', () {
      final missingReferences = <String>[];

      for (final file
          in Directory('assets/data').listSync().whereType<File>().where(
            (file) => file.path.toLowerCase().endsWith('.json'),
          )) {
        final decoded = jsonDecode(file.readAsStringSync());

        _visitJsonStrings(decoded, (value) {
          final reference = value.trim();
          if (reference.isEmpty || !reference.startsWith('assets/')) {
            return;
          }

          if (!File(reference).existsSync()) {
            missingReferences.add('${file.path}: $reference');
          }
        });
      }

      expect(
        missingReferences,
        isEmpty,
        reason:
            'Every non-empty assets/ reference in JSON must point to a file.',
      );
    });

    test('every route references a usable GPX track', () {
      final routes = _readJsonList('assets/data/routes.json');
      final referencedGpxFiles = <String>{};
      final routePointPattern = RegExp(
        r'<(?:[A-Za-z_][\w.-]*:)?(?:trkpt|rtept)\b[^>]*>',
        caseSensitive: false,
      );
      final latitudePattern = RegExp(
        r'''\blat\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      );
      final longitudePattern = RegExp(
        r'''\b(?:lon|lng)\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      );

      for (final route in routes) {
        final routeName = _expectRequiredString(route, 'title', 'route');
        final gpxPath = _expectRequiredString(route, 'gpx', routeName);

        expect(
          gpxPath.startsWith('assets/gpx/') &&
              gpxPath.toLowerCase().endsWith('.gpx'),
          isTrue,
          reason: '$routeName must reference a GPX file in assets/gpx.',
        );
        expect(
          referencedGpxFiles.add(gpxPath),
          isTrue,
          reason: 'Routes must not share the same GPX file: $gpxPath.',
        );

        final gpxFile = File(gpxPath);
        expect(
          gpxFile.existsSync(),
          isTrue,
          reason: '$routeName references missing GPX file $gpxPath.',
        );

        final source = gpxFile.readAsStringSync();
        expect(
          source.toLowerCase(),
          contains('<gpx'),
          reason: '$gpxPath must contain a GPX document.',
        );

        final pointTags = routePointPattern.allMatches(source).toList();
        expect(
          pointTags.length,
          greaterThanOrEqualTo(2),
          reason: '$gpxPath must contain at least two route points.',
        );

        for (final pointTag in pointTags) {
          final tag = pointTag.group(0)!;
          final latitude = double.tryParse(
            latitudePattern.firstMatch(tag)?.group(1) ?? '',
          );
          final longitude = double.tryParse(
            longitudePattern.firstMatch(tag)?.group(1) ?? '',
          );

          expect(
            latitude,
            isNotNull,
            reason: '$gpxPath contains a point without a valid latitude.',
          );
          expect(
            longitude,
            isNotNull,
            reason: '$gpxPath contains a point without a valid longitude.',
          );
          expect(
            latitude,
            inInclusiveRange(-90.0, 90.0),
            reason: '$gpxPath contains an out-of-range latitude.',
          );
          expect(
            longitude,
            inInclusiveRange(-180.0, 180.0),
            reason: '$gpxPath contains an out-of-range longitude.',
          );
        }
      }
    });
  });
}

List<Map<String, dynamic>> _readJsonList(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist.');

  final decoded = jsonDecode(file.readAsStringSync());
  expect(decoded, isA<List<dynamic>>(), reason: '$path must contain a list.');

  final records = <Map<String, dynamic>>[];
  for (final item in decoded as List<dynamic>) {
    expect(
      item,
      isA<Map<String, dynamic>>(),
      reason: 'Every record in $path must be a JSON object.',
    );
    records.add(item as Map<String, dynamic>);
  }
  return records;
}

void _expectUniqueRequiredStrings(
  List<Map<String, dynamic>> records,
  String key,
  String recordType,
) {
  final values = <String>{};

  for (final record in records) {
    final value = _expectRequiredString(record, key, recordType);
    expect(
      values.add(value),
      isTrue,
      reason: 'Duplicate $recordType $key "$value".',
    );
  }
}

String _expectRequiredString(
  Map<String, dynamic> record,
  String key,
  String context,
) {
  final value = record[key];
  expect(value, isA<String>(), reason: '$context.$key must be a string.');
  expect(
    (value as String).trim(),
    isNotEmpty,
    reason: '$context.$key must not be empty.',
  );
  return value.trim();
}

void _expectLocalCoordinates(Map<String, dynamic> record, String context) {
  final latitude = record['lat'];
  final longitude = record['lng'];

  expect(latitude, isA<num>(), reason: '$context.lat must be numeric.');
  expect(longitude, isA<num>(), reason: '$context.lng must be numeric.');
  expect(
    (latitude as num).toDouble(),
    inInclusiveRange(_minimumLocalLatitude, _maximumLocalLatitude),
    reason: '$context.lat must be within the City of Canada Bay area.',
  );
  expect(
    (longitude as num).toDouble(),
    inInclusiveRange(_minimumLocalLongitude, _maximumLocalLongitude),
    reason: '$context.lng must be within the City of Canada Bay area.',
  );
}

void _visitJsonStrings(dynamic value, void Function(String value) visitor) {
  if (value is String) {
    visitor(value);
    return;
  }

  if (value is List<dynamic>) {
    for (final item in value) {
      _visitJsonStrings(item, visitor);
    }
    return;
  }

  if (value is Map<String, dynamic>) {
    for (final item in value.values) {
      _visitJsonStrings(item, visitor);
    }
  }
}
