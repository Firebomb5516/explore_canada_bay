import 'dart:io';

import 'package:explore_canada_bay/screens/explore_screen.dart';
import 'package:explore_canada_bay/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

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
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder.');
}

Finder _semanticsWidget(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
    description: 'Semantics(label: $label)',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppThemeColors.mode = ThemeMode.light;
  });

  testWidgets('route cards use a clear green View route button', (
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

    final mapBadge = find.byKey(const ValueKey('map-context-badge'));
    final mapControls = find.byKey(const ValueKey('map-control-bar'));
    expect(mapBadge, findsOneWidget);
    expect(mapControls, findsOneWidget);
    expect(
      tester.getTopLeft(mapBadge).dy,
      closeTo(tester.getTopLeft(mapControls).dy, 0.5),
    );
    expect(
      tester.getTopRight(mapBadge).dx,
      lessThan(tester.getTopLeft(mapControls).dx),
    );

    final action = find.widgetWithText(FilledButton, 'View route').first;
    expect(action, findsOneWidget);

    final button = tester.widget<FilledButton>(action);
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppThemeColors.accentGreen,
    );
  });

  testWidgets('shared Cabarita marker keeps the park symbol', (tester) async {
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

    final cabaritaMarker = _semanticsWidget('Open Cabarita Park');
    await _pumpUntilFound(tester, cabaritaMarker);

    expect(
      find.descendant(
        of: cabaritaMarker,
        matching: find.byIcon(Icons.park_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cabaritaMarker,
        matching: find.byIcon(Icons.layers_rounded),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'tapping Cabarita marker opens the place before its linked wildlife',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ExploreScreen(
            requestedFilter: 'parks',
            exploreRequestVersion: 1,
            tileProvider: _TransparentTileProvider(),
            assetLoader: _fileAssetLoader,
          ),
        ),
      );

      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('place-list-parks-true')),
      );
      final cabaritaMarker = _semanticsWidget('Open Cabarita Park');
      await _pumpUntilFound(tester, cabaritaMarker);
      await tester.tap(
        find.descendant(
          of: cabaritaMarker,
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cabarita Park'), findsWidgets);
      expect(find.text('What can be found here'), findsOneWidget);
      expect(find.text('Rainbow Lorikeet'), findsOneWidget);
      expect(find.text('Australian Magpie'), findsOneWidget);
      expect(find.text('Eastern Osprey'), findsOneWidget);

      final placeTitle = find.text('Cabarita Park').last;
      final discoveriesHeading = find.text('What can be found here');
      expect(
        tester.getTopLeft(placeTitle).dy,
        lessThan(tester.getTopLeft(discoveriesHeading).dy),
      );
    },
  );
}
