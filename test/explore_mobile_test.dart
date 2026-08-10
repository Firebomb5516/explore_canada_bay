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

Widget _mobileShell({
  double safeTop = 0,
  double safeBottom = 0,
  bool isActive = true,
}) {
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
              isActive: isActive,
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
      find.byKey(const ValueKey('explore-sheet-handle')),
    );

    expect(
      find.byKey(const ValueKey('explore-mobile-map-stack')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('map-context-badge')), findsNothing);
    expect(find.byKey(const ValueKey('explore-route-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-list-desktop')), findsNothing);

    final mapRect = tester.getRect(find.byKey(const ValueKey('explore-map')));
    final collapsedPanelRect = tester.getRect(
      find.byKey(const ValueKey('explorer-panel')),
    );
    expect(mapRect.height, greaterThan(600));
    expect(mapRect.bottom, closeTo(collapsedPanelRect.bottom, 0.5));
    expect(collapsedPanelRect.height, inInclusiveRange(76, 88));
    expect(mapRect.overlaps(collapsedPanelRect), isTrue);
    final collapsedSearch = find.byType(TextField);
    expect(collapsedSearch.hitTestable(), findsNothing);
    if (collapsedSearch.evaluate().isNotEmpty) {
      expect(
        tester.getRect(collapsedSearch).top,
        greaterThanOrEqualTo(collapsedPanelRect.bottom),
      );
    }

    await tester.drag(
      find.byKey(const ValueKey('explore-sheet-handle')),
      const Offset(0, -520),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('route-list-mobile')),
    );
    final expandedPanelRect = tester.getRect(
      find.byKey(const ValueKey('explorer-panel')),
    );
    expect(expandedPanelRect.height, greaterThan(390));
    expect(expandedPanelRect.height, lessThan(mapRect.height * 0.76));
    expect(find.byType(TextField).hitTestable(), findsOneWidget);

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

    final cabaritaPark = find.text('Cabarita Park');
    await tester.ensureVisible(cabaritaPark);
    await tester.pump();
    await tester.tap(cabaritaPark);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    final placeCard = find.byKey(const ValueKey('map-place-card'));
    final selectedSummary = find.byKey(
      const ValueKey('selected-map-sheet-summary'),
    );
    final attribution = find.byKey(const ValueKey('map-attribution'));
    final returnedPanelRect = tester.getRect(
      find.byKey(const ValueKey('explorer-panel')),
    );
    expect(placeCard, findsNothing);
    expect(selectedSummary, findsOneWidget);
    expect(attribution, findsOneWidget);
    expect(returnedPanelRect.height, inInclusiveRange(76, 88));
    expect(
      returnedPanelRect.contains(tester.getCenter(selectedSummary)),
      isTrue,
    );
    expect(find.byTooltip('Place details'), findsOneWidget);
    expect(
      tester.getRect(attribution).bottom,
      lessThanOrEqualTo(returnedPanelRect.top),
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
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('explore-sheet-handle')),
    );

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
    expect(collapsedHeight, inInclusiveRange(76, 88));
    expect(routeAction, findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('explore-sheet-handle')),
      const Offset(0, -420),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await _pumpUntilFound(tester, routeAction);

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
      inInclusiveRange(76, 88),
    );

    final parkWaypoint = _semanticsWidget('Open Park');
    await _pumpUntilFound(tester, parkWaypoint);
    final parkWaypointTarget = find.descendant(
      of: parkWaypoint,
      matching: find.byType(GestureDetector),
    );
    expect(parkWaypointTarget.hitTestable(), findsOneWidget);
    await tester.tap(parkWaypointTarget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey('selected-map-sheet-summary')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('map-place-card')), findsNothing);
    expect(find.text('Park'), findsOneWidget);

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
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('explore-sheet-handle')),
    );

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
    expect(collapsedPanelRect.height, inInclusiveRange(70, 82));
    expect(mapRect.overlaps(collapsedPanelRect), isTrue);

    await tester.drag(
      find.byKey(const ValueKey('explore-sheet-handle')),
      const Offset(0, -180),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await _pumpUntilFound(tester, routeAction);
    expect(
      tester.getSize(find.byKey(const ValueKey('explorer-panel'))).height,
      greaterThan(collapsedPanelRect.height),
    );
    await tester.ensureVisible(routeAction);
    await tester.pump();
    expect(routeAction.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to Explore collapses an open route drawer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_mobileShell());
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('explore-sheet-handle')),
    );

    await tester.drag(
      find.byKey(const ValueKey('explore-sheet-handle')),
      const Offset(0, -520),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.getSize(find.byKey(const ValueKey('explorer-panel'))).height,
      greaterThan(390),
    );

    await tester.pumpWidget(_mobileShell(isActive: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pumpWidget(_mobileShell(isActive: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.getSize(find.byKey(const ValueKey('explorer-panel'))).height,
      inInclusiveRange(76, 88),
    );
    expect(tester.takeException(), isNull);
  });
}
