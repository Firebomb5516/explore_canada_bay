import 'dart:io';

import 'package:explore_canada_bay/models/passport.dart';
import 'package:explore_canada_bay/screens/explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _MemoryPassportStore implements PassportStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _TransparentTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(TileProvider.transparentImage);
  }
}

Future<String> _fileAssetLoader(String path) => File(path).readAsString();

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = 60,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  final visibleText = find
      .byType(Text)
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .whereType<String>()
      .take(30)
      .join(' | ');
  fail('Timed out waiting for $finder. Visible text: $visibleText');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('camera bounds contain every GPX route point', () async {
    const gpxAssets = [
      'assets/gpx/bay_run.gpx',
      'assets/gpx/concord_cycle.gpx',
      'assets/gpx/five_dock_point_to_bayview_park.gpx',
      'assets/gpx/rhodes_bicentenial.gpx',
    ];
    final pointPattern = RegExp(
      r'<(?:trkpt|rtept)\b[^>]*\blat="([^"]+)"[^>]*\blon="([^"]+)"',
      caseSensitive: false,
    );

    for (final asset in gpxAssets) {
      final source = await rootBundle.loadString(asset);
      final points = pointPattern.allMatches(source).map((match) {
        return LatLng(
          double.parse(match.group(1)!),
          double.parse(match.group(2)!),
        );
      }).toList();

      expect(points, isNotEmpty, reason: '$asset should contain route points.');
      expect(
        points.every(ExploreScreen.cameraBoundsContain),
        isTrue,
        reason: '$asset must fit inside the legal map camera area.',
      );
    }
  });

  testWidgets('Cycling filter shows cycling routes instead of place results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ExploreScreen(
          tileProvider: _TransparentTileProvider(),
          assetLoader: _fileAssetLoader,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Bay Run'));

    await tester.tap(find.text('Cycling'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Cycling routes'), findsOneWidget);
    expect(find.text('Concord Cycle'), findsOneWidget);
    expect(find.text('Bay Run'), findsNothing);
  });

  testWidgets('requested GPX route can be recorded once in the passport', (
    tester,
  ) async {
    final passport = PassportController(store: _MemoryPassportStore());

    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ExploreScreen(
          passport: passport,
          requestedRouteId: 'bay_run',
          routeRequestVersion: 1,
          tileProvider: _TransparentTileProvider(),
          assetLoader: _fileAssetLoader,
        ),
      ),
    );

    await _pumpUntilFound(tester, find.text('Bay Run'));
    await _pumpUntilFound(tester, find.text('CURRENT ROUTE'));
    await _pumpUntilFound(
      tester,
      find.byTooltip('Add completed route to passport'),
    );

    await tester.tap(find.byTooltip('Add completed route to passport'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(passport.totalXp, 120);
    expect(passport.totalScans, 0);
    expect(passport.scanHistory.single.source, 'activity');

    await tester.tap(find.byTooltip('Add completed route to passport'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(passport.totalXp, 120);
    expect(passport.totalScans, 0);
  });

  testWidgets('compact landscape layout does not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ExploreScreen(
          tileProvider: _TransparentTileProvider(),
          assetLoader: _fileAssetLoader,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Explore Canada Bay'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Explore Canada Bay'), findsOneWidget);
    expect(find.byType(ExploreScreen), findsOneWidget);
  });
}
