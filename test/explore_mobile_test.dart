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

Widget _mobileShell({double safeTop = 0, double safeBottom = 0}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final safePadding = EdgeInsets.only(top: safeTop, bottom: safeBottom);
        return MediaQuery(
          data: mediaQuery.copyWith(
            padding: safePadding,
            viewPadding: safePadding,
          ),
          child: Scaffold(
            body: ExploreScreen(
              tileProvider: _TransparentTileProvider(),
              assetLoader: _fileAssetLoader,
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: SizedBox(height: 70),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppThemeColors.mode = ThemeMode.light;
  });

  testWidgets('portrait Explore opens route cards over a full-screen map', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_mobileShell(safeTop: 47, safeBottom: 34));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('route-list-mobile')),
    );

    expect(
      find.byKey(const ValueKey('explore-mobile-map-stack')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('explore-route-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-list-desktop')), findsNothing);

    final mapRect = tester.getRect(find.byKey(const ValueKey('explore-map')));
    final collapsedPanelRect = tester.getRect(
      find.byKey(const ValueKey('explorer-panel')),
    );
    expect(mapRect.height, greaterThan(600));
    expect(mapRect.bottom, closeTo(collapsedPanelRect.bottom, 0.5));
    expect(collapsedPanelRect.height, inInclusiveRange(90, 105));
    expect(mapRect.overlaps(collapsedPanelRect), isTrue);

    await tester.drag(
      find.byKey(const ValueKey('explore-sheet-handle')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    final expandedPanelRect = tester.getRect(
      find.byKey(const ValueKey('explorer-panel')),
    );
    expect(expandedPanelRect.height, greaterThan(500));

    await tester.drag(
      find.byKey(const ValueKey('explore-filter-list')),
      const Offset(-260, 0),
    );
    await tester.pump(const Duration(milliseconds: 250));
    final parksFilter = find.text('Parks');
    await _pumpUntilFound(tester, parksFilter);
    await tester.tap(parksFilter);
    await tester.pump(const Duration(milliseconds: 350));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('place-list-parks-false')),
    );

    await tester.tap(find.text('Cabarita Park'));
    await tester.pumpAndSettle();

    final placeCard = find.byKey(const ValueKey('map-place-card'));
    final attribution = find.byKey(const ValueKey('map-attribution'));
    final returnedPanelRect = tester.getRect(
      find.byKey(const ValueKey('explorer-panel')),
    );
    expect(placeCard, findsOneWidget);
    expect(attribution, findsOneWidget);
    expect(returnedPanelRect.height, inInclusiveRange(90, 105));
    expect(tester.getRect(placeCard).bottom, lessThan(returnedPanelRect.top));
    expect(
      tester.getRect(placeCard).overlaps(tester.getRect(attribution)),
      isFalse,
    );

    final zoomIn = find.byTooltip('Zoom in');
    expect(zoomIn, findsOneWidget);
    expect(mapRect.contains(tester.getCenter(zoomIn)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone sheet collapses back to the selected route map', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_mobileShell(safeTop: 24));
    final routeAction = find.byKey(const ValueKey('view-route:bay_run'));
    await _pumpUntilFound(tester, routeAction);

    expect(
      find.byKey(const ValueKey('explore-mobile-map-stack')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('explore-map'))).height,
      greaterThan(450),
    );

    final collapsedHeight = tester
        .getSize(find.byKey(const ValueKey('explorer-panel')))
        .height;
    expect(collapsedHeight, inInclusiveRange(90, 105));
    expect(routeAction.hitTestable(), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('explore-sheet-handle')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(routeAction);
    await tester.pump();
    final actionRect = tester.getRect(routeAction);
    final panelRect = tester.getRect(
      find.byKey(const ValueKey('explorer-panel')),
    );
    expect(actionRect.left, greaterThanOrEqualTo(panelRect.left));
    expect(actionRect.right, lessThanOrEqualTo(panelRect.right));

    await tester.tap(routeAction);
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('selected-route-card')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      tester.getSize(find.byKey(const ValueKey('explore-map'))).height,
      greaterThan(450),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('explorer-panel'))).height,
      inInclusiveRange(90, 105),
    );

    await tester.drag(
      find.byKey(const ValueKey('explore-sheet-handle')),
      const Offset(0, -420),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final fitRoute = find.byTooltip('Show route');
    await tester.ensureVisible(fitRoute);
    await tester.pump();
    expect(fitRoute.hitTestable(), findsOneWidget);
    await tester.tap(fitRoute);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact landscape keeps a draggable handle over the full map', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(568, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_mobileShell());
    final routeAction = find.byKey(const ValueKey('view-route:bay_run'));
    await _pumpUntilFound(tester, routeAction);

    expect(
      find.byKey(const ValueKey('explore-mobile-map-stack')),
      findsOneWidget,
    );
    final mapRect = tester.getRect(find.byKey(const ValueKey('explore-map')));
    final collapsedPanelRect = tester.getRect(
      find.byKey(const ValueKey('explorer-panel')),
    );
    expect(mapRect.height, closeTo(250, 0.5));
    expect(mapRect.bottom, closeTo(collapsedPanelRect.bottom, 0.5));
    expect(collapsedPanelRect.height, inInclusiveRange(84, 94));
    expect(mapRect.overlaps(collapsedPanelRect), isTrue);

    await tester.drag(
      find.byKey(const ValueKey('explore-sheet-handle')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('explorer-panel'))).height,
      greaterThan(collapsedPanelRect.height),
    );
    await tester.ensureVisible(routeAction);
    await tester.pump();
    expect(routeAction.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
