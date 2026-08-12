import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/explore_localizations.dart';
import '../l10n/app_localizations.dart';
import '../models/passport.dart';
import '../services/external_link_service.dart';
import '../theme/app_theme.dart';
import '../widgets/localized_text.dart';

Color get _navy => AppThemeColors.background;
Color get _panel => AppThemeColors.surfaceStrong;

Color get _green => AppThemeColors.accentGreen;
Color get _blue => AppThemeColors.accentBlue;
Color get _cyan => AppThemeColors.accentCyan;
const _brandInk = Color(0xFF061C31);

Color get _textPrimary => AppThemeColors.text;
Color get _textSecondary => AppThemeColors.muted;
Color get _mutedText => AppThemeColors.subtleText;

typedef ExploreAssetLoader = Future<String> Function(String assetPath);

class ExploreScreen extends StatefulWidget {
  static const double _contentSouthLatitude = -33.9100;
  static const double _contentWestLongitude = 151.0600;
  static const double _contentNorthLatitude = -33.8000;
  static const double _contentEastLongitude = 151.1800;

  final PassportController? passport;
  final String? requestedRouteId;
  final int routeRequestVersion;
  final String? requestedFilter;
  final String? requestedPlaceName;
  final int exploreRequestVersion;
  final bool isActive;
  final TileProvider? tileProvider;
  final ExploreAssetLoader? assetLoader;

  const ExploreScreen({
    super.key,
    this.passport,
    this.requestedRouteId,
    this.routeRequestVersion = 0,
    this.requestedFilter,
    this.requestedPlaceName,
    this.exploreRequestVersion = 0,
    this.isActive = true,
    this.tileProvider,
    this.assetLoader,
  });

  @visibleForTesting
  static bool cameraBoundsContain(LatLng point) {
    return point.latitude >= _contentSouthLatitude &&
        point.latitude <= _contentNorthLatitude &&
        point.longitude >= _contentWestLongitude &&
        point.longitude <= _contentEastLongitude;
  }

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final MapController _mapController = MapController();

  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _mobileSheetController =
      DraggableScrollableController();
  ScrollController? _mobileSheetScrollController;
  double _mobileSheetMinimumExtent = 0.14;
  double _mobileSheetMaximumExtent = 0.88;

  static final LatLng _southWest = LatLng(-33.8980, 151.0800);

  static final LatLng _northEast = LatLng(-33.8110, 151.1690);

  static final LatLngBounds _canadaBayBounds = LatLngBounds(
    _southWest,
    _northEast,
  );

  // The opening frame stays intentionally tighter than the legal camera area.
  // Several GPX routes extend west of the overview, so using the overview as a
  // constraint would clip them and could invalidate a route camera fit.
  static final LatLngBounds _contentCameraBounds = LatLngBounds(
    LatLng(
      ExploreScreen._contentSouthLatitude,
      ExploreScreen._contentWestLongitude,
    ),
    LatLng(
      ExploreScreen._contentNorthLatitude,
      ExploreScreen._contentEastLongitude,
    ),
  );

  static final double _maximumZoom = 19;

  static final List<_ExploreFilter> _filters = [
    _ExploreFilter(key: 'all', icon: Icons.grid_view_rounded),
    _ExploreFilter(key: 'routes', icon: Icons.route_rounded),
    _ExploreFilter(key: 'cycling', icon: Icons.pedal_bike_rounded),
    _ExploreFilter(key: 'food', icon: Icons.restaurant_rounded),
    _ExploreFilter(key: 'parks', icon: Icons.park_rounded),
    _ExploreFilter(key: 'gyms', icon: Icons.fitness_center_rounded),
    _ExploreFilter(key: 'community', icon: Icons.groups_rounded),
    _ExploreFilter(key: 'libraries', icon: Icons.local_library_rounded),
    _ExploreFilter(key: 'nature', icon: Icons.eco_rounded),
    _ExploreFilter(key: 'attractions', icon: Icons.star_rounded),
    _ExploreFilter(key: 'toilets', icon: Icons.wc_rounded),
  ];

  List<Map<String, dynamic>> routes = [];
  List<Map<String, dynamic>> locations = [];

  Map<String, dynamic>? selectedRoute;

  List<LatLng> selectedRoutePoints = [];
  List<_GpxWaypoint> selectedRouteWaypoints = [];

  _MapItem? selectedMapItem;

  bool loading = true;
  String? loadingWarning;

  String selectedFilter = 'all';
  String searchQuery = '';

  LatLng currentCentre = LatLng(-33.8545, 151.1245);

  double currentZoom = 12;
  double _minimumZoom = 11;

  EdgeInsets _fitPadding = EdgeInsets.all(32);

  int _handledRouteRequestVersion = -1;
  int _handledExploreRequestVersion = -1;
  int _routeSelectionGeneration = 0;
  String? _loadingRouteKey;
  String? _recordingRouteKey;

  @override
  void initState() {
    super.initState();
    _loadExploreData();
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.routeRequestVersion != oldWidget.routeRequestVersion) {
      _queueRequestedRoute();
    }
    if (widget.exploreRequestVersion != oldWidget.exploreRequestVersion) {
      _queueExploreRequest();
    }
    if (widget.isActive != oldWidget.isActive) {
      _revealMapOnMobile();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mobileSheetController.dispose();
    super.dispose();
  }

  void _revealMapOnMobile() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_mobileSheetController.isAttached) return;
      final scrollController = _mobileSheetScrollController;
      if (scrollController != null && scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
      await _mobileSheetController.animateTo(
        _mobileSheetMinimumExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _toggleMobileExplorerSheet() {
    if (!_mobileSheetController.isAttached) return;
    final collapsed =
        _mobileSheetController.size <= _mobileSheetMinimumExtent + 0.04;
    _mobileSheetController.animateTo(
      collapsed ? _mobileSheetMaximumExtent : _mobileSheetMinimumExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _loadJsonList(
    List<String> possiblePaths, {
    bool optional = false,
  }) async {
    Object? finalError;

    for (final path in possiblePaths) {
      try {
        final source =
            await (widget.assetLoader?.call(path) ??
                rootBundle.loadString(path));

        final decoded = json.decode(source);

        if (decoded is! List) {
          throw FormatException('$path must contain a JSON list.');
        }

        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      } catch (error) {
        finalError = error;
      }
    }

    if (optional) {
      return [];
    }

    throw Exception(
      'Could not load ${possiblePaths.join(' or ')}.\n'
      '$finalError',
    );
  }

  Future<void> _loadExploreData() async {
    setState(() {
      loading = true;
      loadingWarning = null;
    });

    final warnings = <String>[];

    var loadedRoutes = <Map<String, dynamic>>[];

    var loadedLocations = <Map<String, dynamic>>[];

    try {
      loadedRoutes = await _loadJsonList([
        'assets/data/routes.json',
        'assets/routes.json',
      ]);
    } catch (error) {
      debugPrint('Routes loading error: $error');

      warnings.add('routes.json');
    }

    try {
      loadedLocations = await _loadJsonList([
        'assets/data/locations.json',
        'assets/locations.json',
      ]);
    } catch (error) {
      debugPrint('Locations loading error: $error');

      warnings.add('locations.json');
    }

    final foodLocations = await _loadJsonList([
      'assets/data/food.json',
      'assets/food.json',
    ], optional: true);

    final biodiversityLocations = await _loadJsonList([
      'assets/data/biodiversity.json',
      'assets/biodiversity.json',
    ], optional: true);

    final environmentalLocations = await _loadJsonList([
      'assets/data/environment.json',
    ], optional: true);

    if (!mounted) return;

    setState(() {
      routes = loadedRoutes;

      locations = _removeDuplicates([
        ...loadedLocations,
        ...foodLocations,
        ...biodiversityLocations,
        ...environmentalLocations,
      ]);

      loadingWarning = warnings.isEmpty
          ? null
          : _exploreL10n.text('dataLoadWarning', {
              'files': warnings.join(', '),
            });

      loading = false;
    });

    _queueRequestedRoute();
    _queueExploreRequest();
  }

  List<Map<String, dynamic>> _removeDuplicates(
    List<Map<String, dynamic>> items,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final item in items) {
      final stableId = _asText(item['id']).trim();
      final key = stableId.isNotEmpty
          ? 'id:$stableId'
          : [
              item['name'] ?? item['title'] ?? '',
              item['lat'] ?? '',
              item['lng'] ?? '',
            ].join('|').toLowerCase();

      if (seen.add(key)) {
        result.add(item);
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // BASIC HELPERS
  // ---------------------------------------------------------------------------

  String _asText(dynamic value, [String fallback = '']) {
    return value?.toString() ?? fallback;
  }

  ExploreLocalizations get _exploreL10n => ExploreLocalizations.of(context);

  Map<String, dynamic> _contentFor(Map<String, dynamic> item) {
    return _exploreL10n.contentFor(item);
  }

  String _normalise(String value) {
    return value
        .toLowerCase()
        // Remove punctuation without discarding Chinese, Korean, Devanagari
        // or accented Latin letters.
        .replaceAll(
          RegExp(
            r'[\u0000-\u002F\u003A-\u0040\u005B-\u0060\u007B-\u00BF\u2000-\u206F]+',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _routeKey(Map<String, dynamic> route) {
    return _asText(
      route['id'],
      _asText(route['title'], 'route-${route.hashCode}'),
    );
  }

  bool _isSelectedRoute(Map<String, dynamic> route) {
    if (selectedRoute == null) {
      return false;
    }

    return _routeKey(route) == _routeKey(selectedRoute!);
  }

  LatLng? _pointFromItem(Map<String, dynamic> item) {
    final rawLatitude = item['lat'];
    final rawLongitude = item['lng'];

    final latitude = rawLatitude is num
        ? rawLatitude.toDouble()
        : double.tryParse(rawLatitude?.toString() ?? '');

    final longitude = rawLongitude is num
        ? rawLongitude.toDouble()
        : double.tryParse(rawLongitude?.toString() ?? '');

    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  // ---------------------------------------------------------------------------
  // PLACE CATEGORIES
  // ---------------------------------------------------------------------------

  _PlaceKind _placeKindFromItem(Map<String, dynamic> item) {
    final value = _normalise(
      [item['type'], item['category']].where((item) => item != null).join(' '),
    );

    if (value.contains('food') ||
        value.contains('cafe') ||
        value.contains('coffee') ||
        value.contains('restaurant')) {
      return _PlaceKind.food;
    }

    if (value.contains('park') ||
        value.contains('reserve') ||
        value.contains('garden') ||
        value.contains('playground')) {
      return _PlaceKind.park;
    }

    if (value.contains('gym') ||
        value.contains('fitness') ||
        value.contains('exercise')) {
      return _PlaceKind.gym;
    }

    if (value.contains('library')) {
      return _PlaceKind.library;
    }

    if (value.contains('community') ||
        value.contains('club') ||
        value.contains('centre')) {
      return _PlaceKind.community;
    }

    if (value.contains('biodiversity') ||
        value.contains('wildlife') ||
        value.contains('bird') ||
        value.contains('plant') ||
        value.contains('tree') ||
        value.contains('mangrove') ||
        value.contains('saltmarsh') ||
        value.contains('mammal') ||
        value.contains('amphibian') ||
        value.contains('frog') ||
        value.contains('reptile') ||
        value.contains('insect') ||
        value.contains('pollinator') ||
        value.contains('marine animal') ||
        value.contains('crustacean') ||
        value.contains('habitat') ||
        value.contains('ecology')) {
      return _PlaceKind.biodiversity;
    }

    if (value.contains('attraction') ||
        value.contains('landmark') ||
        value.contains('heritage') ||
        value.contains('historic') ||
        value.contains('waterfront') ||
        value.contains('lookout') ||
        value.contains('museum') ||
        value.contains('poi') ||
        value == 'place') {
      return _PlaceKind.attraction;
    }

    if (value.contains('toilet')) {
      return _PlaceKind.toilet;
    }

    return _PlaceKind.generic;
  }

  IconData _iconForKind(_PlaceKind kind) {
    switch (kind) {
      case _PlaceKind.food:
        return Icons.restaurant_rounded;

      case _PlaceKind.park:
        return Icons.park_rounded;

      case _PlaceKind.gym:
        return Icons.fitness_center_rounded;

      case _PlaceKind.library:
        return Icons.local_library_rounded;

      case _PlaceKind.community:
        return Icons.groups_rounded;

      case _PlaceKind.biodiversity:
        return Icons.eco_rounded;

      case _PlaceKind.attraction:
        return Icons.star_rounded;

      case _PlaceKind.toilet:
        return Icons.wc_rounded;

      case _PlaceKind.generic:
        return Icons.place_rounded;
    }
  }

  Color _colourForKind(_PlaceKind kind) {
    switch (kind) {
      case _PlaceKind.food:
        return Colors.orangeAccent;

      case _PlaceKind.park:
        return _green;

      case _PlaceKind.gym:
        return Colors.redAccent;

      case _PlaceKind.library:
        return _blue;

      case _PlaceKind.community:
        return _blue;

      case _PlaceKind.biodiversity:
        return Color(0xFF70C764);

      case _PlaceKind.attraction:
        return Color(0xFFA76EE8);

      case _PlaceKind.toilet:
        return Color(0xFF9B6DE3);

      case _PlaceKind.generic:
        return Color(0xFF2C6DA8);
    }
  }

  String _labelForKind(_PlaceKind kind) {
    switch (kind) {
      case _PlaceKind.food:
        return _exploreL10n.kindLabel('food');

      case _PlaceKind.park:
        return _exploreL10n.kindLabel('park');

      case _PlaceKind.gym:
        return _exploreL10n.kindLabel('gym');

      case _PlaceKind.library:
        return _exploreL10n.kindLabel('library');

      case _PlaceKind.community:
        return _exploreL10n.kindLabel('community');

      case _PlaceKind.biodiversity:
        return _exploreL10n.kindLabel('biodiversity');

      case _PlaceKind.attraction:
        return _exploreL10n.kindLabel('attraction');

      case _PlaceKind.toilet:
        return _exploreL10n.kindLabel('toilet');

      case _PlaceKind.generic:
        return _exploreL10n.kindLabel('checkpoint');
    }
  }

  // ---------------------------------------------------------------------------
  // FILTERING
  // ---------------------------------------------------------------------------

  bool _matchesSearch(Map<String, dynamic> item) {
    final query = _normalise(searchQuery);

    if (query.isEmpty) {
      return true;
    }

    final searchableText = _normalise(_exploreL10n.searchableText(item));

    return query
        .split(' ')
        .where((word) => word.isNotEmpty)
        .every(searchableText.contains);
  }

  bool _matchesLocationFilter(Map<String, dynamic> item) {
    if (searchQuery.trim().isNotEmpty || selectedFilter == 'all') {
      return true;
    }

    if (selectedFilter == 'routes' || selectedFilter == 'cycling') {
      return false;
    }

    final searchable = _normalise(
      [
        item['name'],
        item['title'],
        item['type'],
        item['category'],
      ].where((value) => value != null).join(' '),
    );

    final kind = _placeKindFromItem(item);

    switch (selectedFilter) {
      case 'food':
        return kind == _PlaceKind.food;

      case 'parks':
        return kind == _PlaceKind.park;

      case 'gyms':
        return kind == _PlaceKind.gym;

      case 'community':
        return kind == _PlaceKind.community;

      case 'libraries':
        return searchable.contains('library');

      case 'nature':
        return kind == _PlaceKind.biodiversity;

      case 'attractions':
        return kind == _PlaceKind.attraction;

      case 'toilets':
        return kind == _PlaceKind.toilet;

      default:
        return true;
    }
  }

  List<Map<String, dynamic>> get visibleRoutes {
    if (selectedFilter == 'cycling') {
      return routes.where((route) {
        final category = _normalise(_asText(route['category']));
        return category.contains('cycling') && _matchesSearch(route);
      }).toList();
    }

    if (searchQuery.trim().isEmpty &&
        selectedFilter != 'all' &&
        selectedFilter != 'routes') {
      return [];
    }

    return routes.where(_matchesSearch).toList();
  }

  List<Map<String, dynamic>> get visibleLocations {
    return locations.where((location) {
      return _matchesLocationFilter(location) && _matchesSearch(location);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // MAP ITEMS
  // ---------------------------------------------------------------------------

  List<_MapItem> get mapItems {
    final items = <_MapItem>[];

    for (final location in visibleLocations) {
      final item = _mapItemFromLocation(location);

      if (item != null) {
        items.add(item);
      }
    }

    if (selectedRoute == null) {
      for (final route in visibleRoutes) {
        final point = _pointFromItem(route);

        if (point == null) {
          continue;
        }

        final content = _contentFor(route);
        final title = _asText(content['title'], _exploreL10n.text('route'));
        final routeId = _routeKey(route);

        items.add(
          _MapItem(
            id: 'route:$routeId',
            title: title,
            subtitle: _exploreL10n.text('viewRoute'),
            point: point,
            icon: Icons.route_rounded,
            colour: _green,
            type: _MapItemType.route,
            route: route,
          ),
        );
      }

      return items;
    }

    final selectedContent = _contentFor(selectedRoute!);
    final routeTitle = _asText(
      selectedContent['title'],
      _exploreL10n.text('selectedRoute'),
    );

    if (selectedRoutePoints.isNotEmpty) {
      items.add(
        _MapItem(
          id: 'selected-route-start',
          title: _exploreL10n.text('routeStart'),
          subtitle: routeTitle,
          point: selectedRoutePoints.first,
          icon: Icons.play_arrow_rounded,
          colour: _green,
          type: _MapItemType.start,
        ),
      );

      if (selectedRoutePoints.length > 1) {
        items.add(
          _MapItem(
            id: 'selected-route-finish',
            title: _exploreL10n.text('routeFinish'),
            subtitle: routeTitle,
            point: selectedRoutePoints.last,
            icon: Icons.flag_rounded,
            colour: Colors.orangeAccent,
            type: _MapItemType.finish,
          ),
        );
      }
    }

    for (var index = 0; index < selectedRouteWaypoints.length; index++) {
      final waypoint = selectedRouteWaypoints[index];

      final kind = _placeKindFromText(waypoint.type);

      items.add(
        _MapItem(
          id: 'waypoint:$index:${waypoint.name}',
          title: _localizedWaypointName(waypoint.name),
          subtitle: _labelForKind(kind),
          point: waypoint.point,
          icon: _iconForKind(kind),
          colour: _colourForKind(kind),
          type: _MapItemType.waypoint,
          data: {
            'id': 'route-waypoint:$index:${waypoint.name}',
            'name': _localizedWaypointName(waypoint.name),
            'description': waypoint.description.isEmpty
                ? _exploreL10n.text('discoverPlace')
                : waypoint.description,
            'type': waypoint.type,
          },
        ),
      );
    }

    return items;
  }

  _MapItem? _mapItemFromLocation(Map<String, dynamic> location) {
    final point = _pointFromItem(location);

    if (point == null) {
      return null;
    }

    final kind = _placeKindFromItem(location);
    final content = _contentFor(location);
    final title = _asText(
      content['name'],
      _asText(content['title'], _exploreL10n.text('kind.checkpoint')),
    );
    final stableId = _asText(location['id']).trim();

    return _MapItem(
      id: stableId.isEmpty
          ? 'location:${location['lat']}:${location['lng']}'
          : 'location:$stableId',
      title: title,
      subtitle: _labelForKind(kind),
      point: point,
      icon: _iconForKind(kind),
      colour: _colourForKind(kind),
      type: _MapItemType.location,
      data: location,
    );
  }

  String _localizedWaypointName(String name) {
    switch (_normalise(name)) {
      case 'playground':
        return _exploreL10n.text('waypointPlayground');
      case 'park':
        return _exploreL10n.text('waypointPark');
      case 'restrooms':
      case 'restroom':
        return _exploreL10n.text('waypointRestrooms');
      default:
        return name.isEmpty ? _exploreL10n.text('routeCheckpoint') : name;
    }
  }

  _PlaceKind _placeKindFromText(String value) {
    return _placeKindFromItem({'type': value});
  }

  // ---------------------------------------------------------------------------
  // CAMERA
  // ---------------------------------------------------------------------------

  double _mercatorY(double latitude) {
    final radians = latitude * math.pi / 180;

    final sinLatitude = math.sin(radians).clamp(-0.9999, 0.9999);

    return 0.5 -
        math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi);
  }

  double _calculateFitZoom(Size mapSize, EdgeInsets padding) {
    final availableWidth = math.max(
      1.0,
      mapSize.width - padding.left - padding.right,
    );

    final availableHeight = math.max(
      1.0,
      mapSize.height - padding.top - padding.bottom,
    );

    final westX = (_southWest.longitude + 180) / 360;

    final eastX = (_northEast.longitude + 180) / 360;

    final northY = _mercatorY(_northEast.latitude);

    final southY = _mercatorY(_southWest.latitude);

    final longitudeSpan = (eastX - westX).abs();

    final latitudeSpan = (southY - northY).abs();

    final zoomX = math.log(availableWidth / (256 * longitudeSpan)) / math.ln2;

    final zoomY = math.log(availableHeight / (256 * latitudeSpan)) / math.ln2;

    // Keep the same constrained Canada Bay overview, but start close enough
    // that local streets and markers are immediately useful.
    return math.min(zoomX, zoomY) + 0.90;
  }

  void _fitCanadaBay() {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: _canadaBayBounds,
        padding: _fitPadding,
        minZoom: _minimumZoom,
        maxZoom: _minimumZoom + 0.03,
      ),
    );
  }

  void _zoomIn() {
    final nextZoom = (currentZoom + 1)
        .clamp(_minimumZoom, _maximumZoom)
        .toDouble();

    _mapController.move(currentCentre, nextZoom);
  }

  void _zoomOut() {
    final nextZoom = (currentZoom - 1)
        .clamp(_minimumZoom, _maximumZoom)
        .toDouble();

    _mapController.move(currentCentre, nextZoom);
  }

  int _zoomLevelGroup(double zoom) {
    if (zoom >= 15) {
      return 3;
    }

    if (zoom >= 13.5) {
      return 2;
    }

    return 1;
  }

  // ---------------------------------------------------------------------------
  // ROUTES AND GPX
  // ---------------------------------------------------------------------------

  void _queueRequestedRoute() {
    final requestedId = widget.requestedRouteId?.trim();
    final requestVersion = widget.routeRequestVersion;

    if (requestedId == null ||
        requestedId.isEmpty ||
        requestVersion == _handledRouteRequestVersion ||
        loading ||
        routes.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestVersion == _handledRouteRequestVersion) return;

      Map<String, dynamic>? requestedRoute;
      final normalisedRequestedId = _normalise(requestedId);
      for (final route in routes) {
        if (_normalise(_routeKey(route)) == normalisedRequestedId ||
            _normalise(_asText(route['title'])) == normalisedRequestedId) {
          requestedRoute = route;
          break;
        }
      }

      _handledRouteRequestVersion = requestVersion;

      if (requestedRoute == null) {
        _showMessage(_exploreL10n.text('routeNotFound'));
        return;
      }

      _selectRoute(requestedRoute);
    });
  }

  void _queueExploreRequest() {
    final requestVersion = widget.exploreRequestVersion;
    final requestedFilter = widget.requestedFilter?.trim();
    final requestedPlace = widget.requestedPlaceName?.trim();
    if (requestVersion == _handledExploreRequestVersion ||
        loading ||
        (requestedPlace != null &&
            requestedPlace.isNotEmpty &&
            locations.isEmpty) ||
        ((requestedFilter == null || requestedFilter.isEmpty) &&
            (requestedPlace == null || requestedPlace.isEmpty))) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestVersion == _handledExploreRequestVersion) return;
      _handledExploreRequestVersion = requestVersion;

      String? requestedFilterKey;
      if (requestedFilter != null) {
        final normalisedFilter = _normalise(requestedFilter);
        for (final filter in _filters) {
          if (_normalise(filter.key) == normalisedFilter ||
              _normalise(_exploreL10n.filterLabel(filter.key)) ==
                  normalisedFilter ||
              _normalise(
                    const ExploreLocalizations(
                      Locale('en'),
                    ).filterLabel(filter.key),
                  ) ==
                  normalisedFilter) {
            requestedFilterKey = filter.key;
            break;
          }
        }
      }
      final nextFilter = requestedFilterKey ?? 'all';
      _searchController.clear();

      _MapItem? requestedItem;
      if (requestedPlace != null && requestedPlace.isNotEmpty) {
        final normalisedPlace = _normalise(requestedPlace);
        for (final location in locations) {
          final item = _mapItemFromLocation(location);
          final canonicalName = _asText(
            location['name'],
            _asText(location['title']),
          );
          final stableId = _asText(location['id']);
          if (item != null &&
              (_normalise(item.title) == normalisedPlace ||
                  _normalise(canonicalName) == normalisedPlace ||
                  _normalise(stableId) == normalisedPlace)) {
            requestedItem = item;
            break;
          }
        }
      }

      _routeSelectionGeneration++;
      setState(() {
        selectedFilter = nextFilter;
        searchQuery = '';
        selectedRoute = null;
        selectedRoutePoints = [];
        selectedRouteWaypoints = [];
        selectedMapItem = requestedItem;
        _loadingRouteKey = null;
      });

      if (requestedItem != null) {
        _revealMapOnMobile();
        _mapController.move(
          requestedItem.point,
          math.max(_minimumZoom + 2, 14),
        );
      } else if (requestedPlace != null && requestedPlace.isNotEmpty) {
        _showMessage(_exploreL10n.text('placeNotFound'));
      }
    });
  }

  Future<void> _selectRoute(Map<String, dynamic> route) async {
    final routeKey = _routeKey(route);
    final rawPath = _asText(route['gpx']).trim();
    final selectionGeneration = ++_routeSelectionGeneration;
    _searchController.clear();

    setState(() {
      selectedFilter = 'routes';
      searchQuery = '';
      selectedRoute = route;
      selectedRoutePoints = [];
      selectedRouteWaypoints = [];
      selectedMapItem = null;
      _loadingRouteKey = rawPath.isEmpty ? null : routeKey;
    });
    _revealMapOnMobile();

    if (rawPath.isEmpty) {
      final point = _pointFromItem(route);

      if (point != null) {
        _mapController.move(point, math.max(_minimumZoom + 2, 14));
      }

      _showMessage(_exploreL10n.text('noGpx'));

      return;
    }

    try {
      final gpx = await _loadGpx(rawPath);

      final points = _extractTrackPoints(gpx);

      final waypoints = _extractWaypoints(gpx);

      if (!mounted ||
          selectionGeneration != _routeSelectionGeneration ||
          !_isSelectedRoute(route)) {
        return;
      }

      setState(() {
        selectedRoutePoints = points;
        selectedRouteWaypoints = waypoints;
        _loadingRouteKey = null;
      });

      if (points.length > 1) {
        _fitSelectedRoute();
      } else {
        final point = points.isNotEmpty ? points.first : _pointFromItem(route);

        if (point != null) {
          _mapController.move(point, math.max(_minimumZoom + 2, 14));
        }

        if (points.isEmpty) {
          _showMessage(_exploreL10n.text('gpxNoLine'));
        }
      }
    } catch (error) {
      debugPrint('GPX loading error: $error');

      if (!mounted ||
          selectionGeneration != _routeSelectionGeneration ||
          !_isSelectedRoute(route)) {
        return;
      }

      setState(() {
        _loadingRouteKey = null;
      });
      _showMessage(_exploreL10n.text('gpxFailed'));
    }
  }

  void _fitSelectedRoute() {
    if (selectedRoutePoints.length < 2) {
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(selectedRoutePoints),
        padding: EdgeInsets.all(50),
        minZoom: _minimumZoom,
        maxZoom: 17,
      ),
    );
  }

  void _clearSelectedRoute() {
    _routeSelectionGeneration++;

    setState(() {
      selectedRoute = null;
      selectedRoutePoints = [];
      selectedRouteWaypoints = [];
      selectedMapItem = null;
      _loadingRouteKey = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitCanadaBay();
      }
    });
  }

  Future<void> _completeSelectedRoute() async {
    final route = selectedRoute;
    final passport = widget.passport;
    if (route == null || passport == null) {
      _showMessage(_exploreL10n.text('passportUnavailable'));
      return;
    }

    final routeKey = _routeKey(route);
    if (_loadingRouteKey == routeKey) {
      _showMessage(_exploreL10n.text('waitForRoute'));
      return;
    }
    if (selectedRoutePoints.length < 2) {
      _showMessage(_exploreL10n.text('cannotCompleteRoute'));
      return;
    }
    if (_recordingRouteKey != null) {
      return;
    }

    final canonicalTitle = _asText(
      route['title'],
      _exploreL10n.text('localRoute'),
    );
    final title = _asText(
      _contentFor(route)['title'],
      _exploreL10n.text('localRoute'),
    );
    final points = int.tryParse(_asText(route['xp'], '0'))?.clamp(0, 500) ?? 0;
    final category = _normalise(_asText(route['category']));

    setState(() {
      _recordingRouteKey = routeKey;
    });

    try {
      final result = await passport.recordActivity(
        activityId: 'route-complete:$routeKey',
        placeName: canonicalTitle,
        points: points,
        badgeId: category.contains('walking') ? 'foreshore_walker' : null,
      );
      if (!mounted) return;
      final xp = result.xpAwarded > 0 ? ' · +${result.xpAwarded} XP' : '';
      _showMessage(
        result.duplicate
            ? _exploreL10n.text('alreadyRecorded', {'title': title})
            : _exploreL10n.text('addedToPassport', {'title': title, 'xp': xp}),
      );
    } catch (error) {
      debugPrint('Route completion error: $error');
      if (mounted) {
        _showMessage(_exploreL10n.text('routeSaveFailed'));
      }
    } finally {
      if (mounted && _recordingRouteKey == routeKey) {
        setState(() {
          _recordingRouteKey = null;
        });
      }
    }
  }

  Future<String> _loadGpx(String rawPath) async {
    final cleaned = rawPath.replaceAll('\\', '/').trim();

    final candidates = <String>{};

    void addCandidate(String path) {
      if (path.trim().isEmpty) {
        return;
      }

      candidates.add(path);

      if (!path.toLowerCase().endsWith('.gpx')) {
        candidates.add('$path.gpx');
      }
    }

    addCandidate(cleaned);

    if (!cleaned.startsWith('assets/')) {
      addCandidate('assets/gpx/$cleaned');
    }

    Object? lastError;

    for (final path in candidates) {
      try {
        return await (widget.assetLoader?.call(path) ??
            rootBundle.loadString(path));
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception(
      'Could not load GPX.\n'
      '${candidates.join(', ')}\n'
      '$lastError',
    );
  }

  List<LatLng> _extractTrackPoints(String gpx) {
    final points = <LatLng>[];

    final trackExpression = RegExp(
      r'<trkpt\b([^>]*)>',
      caseSensitive: false,
      multiLine: true,
    );

    for (final match in trackExpression.allMatches(gpx)) {
      final point = _attributesToPoint(match.group(1) ?? '');

      if (point != null) {
        points.add(point);
      }
    }

    if (points.isNotEmpty) {
      return points;
    }

    final routeExpression = RegExp(
      r'<rtept\b([^>]*)>',
      caseSensitive: false,
      multiLine: true,
    );

    for (final match in routeExpression.allMatches(gpx)) {
      final point = _attributesToPoint(match.group(1) ?? '');

      if (point != null) {
        points.add(point);
      }
    }

    return points;
  }

  List<_GpxWaypoint> _extractWaypoints(String gpx) {
    final waypoints = <_GpxWaypoint>[];

    final expression = RegExp(
      r'<wpt\b([^>]*)>([\s\S]*?)</wpt>',
      caseSensitive: false,
      multiLine: true,
    );

    for (final match in expression.allMatches(gpx)) {
      final point = _attributesToPoint(match.group(1) ?? '');

      if (point == null) {
        continue;
      }

      final body = match.group(2) ?? '';

      final name = _xmlValue(body, 'name');

      final type = _xmlValue(body, 'type');
      final waypointDescription = _xmlValue(body, 'desc');
      final comment = _xmlValue(body, 'cmt');

      waypoints.add(
        _GpxWaypoint(
          name: name.isEmpty ? _exploreL10n.text('routeCheckpoint') : name,
          type: type.isEmpty ? _guessType(name) : type,
          point: point,
          description: waypointDescription.isEmpty
              ? comment
              : waypointDescription,
        ),
      );
    }

    return waypoints;
  }

  LatLng? _attributesToPoint(String attributes) {
    final latitudeMatch = RegExp(
      r'''lat=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(attributes);

    final longitudeMatch = RegExp(
      r'''lon=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(attributes);

    if (latitudeMatch == null || longitudeMatch == null) {
      return null;
    }

    final latitude = double.tryParse(latitudeMatch.group(1) ?? '');

    final longitude = double.tryParse(longitudeMatch.group(1) ?? '');

    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  String _xmlValue(String xml, String tag) {
    final match = RegExp(
      '<$tag>([\\s\\S]*?)</$tag>',
      caseSensitive: false,
    ).firstMatch(xml);

    if (match == null) {
      return '';
    }

    return match
        .group(1)!
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .trim();
  }

  String _guessType(String name) {
    final value = name.toLowerCase();

    if (value.contains('cafe') || value.contains('restaurant')) {
      return 'food';
    }

    if (value.contains('park') || value.contains('reserve')) {
      return 'park';
    }

    if (value.contains('waterfront') ||
        value.contains('house') ||
        value.contains('heritage') ||
        value.contains('lookout')) {
      return 'attraction';
    }

    if (value.contains('bird') ||
        value.contains('wildlife') ||
        value.contains('mangrove')) {
      return 'biodiversity';
    }

    return 'checkpoint';
  }

  // ---------------------------------------------------------------------------
  // MARKER INTERACTION
  // ---------------------------------------------------------------------------

  void _handleMarkerTap(_MapItem item) {
    if (item.type == _MapItemType.route && item.route != null) {
      _selectRoute(item.route!);
      return;
    }

    final discoveries = _boundDiscoveriesFor(item);
    if (item.data != null &&
        (item.type == _MapItemType.waypoint || discoveries.isNotEmpty)) {
      _showPlaceDetails(item, discoveries: discoveries);
      return;
    }

    // Normal checkpoints only open their card.
    // The camera does not move or zoom.
    setState(() {
      selectedMapItem = item;
    });
    _revealMapOnMobile();
  }

  List<_MapItem> _boundDiscoveriesFor(_MapItem place) {
    final placeId = _asText(place.data?['id']).trim();
    if (placeId.isEmpty) return const <_MapItem>[];

    return locations
        .where((location) => _asText(location['placeId']).trim() == placeId)
        .map(_mapItemFromLocation)
        .whereType<_MapItem>()
        .toList(growable: false);
  }

  List<List<_MapItem>> _groupedMapItems() {
    final items = mapItems;
    final visiblePlaceIds = items
        .map((item) => _asText(item.data?['id']).trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final boundTargetIds = items
        .map((item) => _asText(item.data?['placeId']).trim())
        .where(visiblePlaceIds.contains)
        .toSet();
    final groups = <String, List<_MapItem>>{};
    for (final item in items) {
      final ownPlaceId = _asText(item.data?['id']).trim();
      final boundPlaceId = _asText(item.data?['placeId']).trim();
      final key =
          boundPlaceId.isNotEmpty && visiblePlaceIds.contains(boundPlaceId)
          ? 'place:$boundPlaceId'
          : boundTargetIds.contains(ownPlaceId)
          ? 'place:$ownPlaceId'
          : '${item.point.latitude.toStringAsFixed(6)}|'
                '${item.point.longitude.toStringAsFixed(6)}';
      groups.putIfAbsent(key, () => <_MapItem>[]).add(item);
    }
    return groups.values.toList(growable: false);
  }

  _MapItem _primaryItemForGroup(List<_MapItem> items) {
    final boundPlaceIds = items
        .map((item) => _asText(item.data?['placeId']).trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final item in items) {
      if (boundPlaceIds.contains(_asText(item.data?['id']).trim())) {
        return item;
      }
    }
    return items.first;
  }

  void _showMarkerGroup(List<_MapItem> items) {
    final primary = _primaryItemForGroup(items);
    final discoveries = items
        .where((item) => item.id != primary.id)
        .toList(growable: false);
    final primaryId = _asText(primary.data?['id']).trim();
    final boundDiscoveries = discoveries
        .where((item) => _asText(item.data?['placeId']).trim() == primaryId)
        .toList(growable: false);
    if (primary.data != null && boundDiscoveries.isNotEmpty) {
      _showPlaceDetails(primary, discoveries: boundDiscoveries);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final availableHeight = MediaQuery.sizeOf(context).height;
        final maximumSheetHeight = math.max(220.0, availableHeight * 0.78);
        final desiredSheetHeight = 92.0 + (items.length * 68.0);
        final sheetHeight = math.min(desiredSheetHeight, maximumSheetHeight);

        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            key: const ValueKey('marker-group-sheet'),
            width: double.infinity,
            height: sheetHeight,
            constraints: BoxConstraints(maxWidth: 560),
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppThemeColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  _exploreL10n.text('discoveriesHere', {'count': items.length}),
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    key: const ValueKey('marker-group-list'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: AppThemeColors.border),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        minTileHeight: 64,
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: item.colour.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item.icon, color: item.colour),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _textSecondary),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: _textSecondary,
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _handleMarkerTap(item);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Marker> _buildMarkers() {
    final headSize = currentZoom >= 15
        ? 50.0
        : currentZoom >= 13.5
        ? 44.0
        : 38.0;

    return _groupedMapItems().map((group) {
      final item = _primaryItemForGroup(group);
      final selected = group.any(
        (candidate) => selectedMapItem?.id == candidate.id,
      );
      final grouped = group.length > 1;

      return Marker(
        key: ValueKey(
          grouped ? 'map-marker-group:${item.id}' : 'map-marker:${item.id}',
        ),
        point: item.point,
        width: headSize + 12,
        height: headSize + 17,

        // Keep this alignment because it
        // correctly anchors the marker tip.
        alignment: Alignment.topCenter,

        child: Semantics(
          button: true,
          label: _exploreL10n.text('openPlace', {'place': item.title}),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              grouped ? _showMarkerGroup(group) : _handleMarkerTap(item);
            },
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: headSize - 8,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: item.colour,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  width: headSize,
                  height: headSize,
                  decoration: BoxDecoration(
                    color: item.colour,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.72),
                      width: selected ? 3 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: selected ? 14 : 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      key: ValueKey('map-marker-icon:${item.id}'),
                      color: Colors.white,
                      size: headSize * 0.44,
                    ),
                  ),
                ),
                if (grouped)
                  Positioned(
                    top: -2,
                    right: 1,
                    child: Container(
                      constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _brandInk,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${group.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // LAYOUT
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: ColoredBox(
        color: AppThemeColors.background,
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 980;

              if (desktop) {
                final panelWidth = constraints.maxWidth >= 1320 ? 430.0 : 390.0;
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: panelWidth,
                        child: _buildExplorerPanel(desktop: true),
                      ),
                      SizedBox(width: 16),
                      Expanded(child: _buildMapPanel(desktop: true)),
                    ],
                  ),
                );
              }

              // The mobile map is the primary canvas. Discovery controls live
              // in a draggable sheet so newcomers can inspect the map first,
              // then pull routes and places up without navigating away.
              final collapsedSheetHeight = constraints.maxHeight < 360
                  ? 76.0
                  : 82.0;
              final minimumSheetExtent =
                  (collapsedSheetHeight / constraints.maxHeight)
                      .clamp(0.10, 0.42)
                      .toDouble();
              final panelContentWidth = constraints.maxWidth - 32;
              final narrowPanel = panelContentWidth < 320;
              final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
              final scaledTextAllowance = ((textScale - 1).clamp(0.0, 1.0) * 72)
                  .toDouble();
              final desiredExpandedHeight =
                  collapsedSheetHeight +
                  342 +
                  (selectedRoute == null
                      ? 0
                      : narrowPanel
                      ? 126
                      : 78) +
                  (loadingWarning == null ? 0 : 68) +
                  scaledTextAllowance;
              final maximumSheetCeiling = constraints.maxHeight < 520
                  ? 0.94
                  : 0.76;
              final minimumExpandedExtent = math.max(
                minimumSheetExtent + 0.18,
                0.42,
              );
              final maximumSheetExtent =
                  (desiredExpandedHeight / constraints.maxHeight)
                      .clamp(minimumExpandedExtent, maximumSheetCeiling)
                      .toDouble();
              _mobileSheetMinimumExtent = minimumSheetExtent;
              _mobileSheetMaximumExtent = maximumSheetExtent;

              return Stack(
                key: const ValueKey('explore-mobile-map-stack'),
                children: [
                  Positioned.fill(
                    child: _buildMapPanel(
                      desktop: false,
                      fullBleed: true,
                      mobileBottomInset: collapsedSheetHeight,
                    ),
                  ),
                  Positioned.fill(
                    child: DraggableScrollableSheet(
                      key: const ValueKey('explore-route-sheet'),
                      controller: _mobileSheetController,
                      initialChildSize: minimumSheetExtent,
                      minChildSize: minimumSheetExtent,
                      maxChildSize: maximumSheetExtent,
                      snap: true,
                      shouldCloseOnMinExtent: false,
                      builder: (context, scrollController) {
                        _mobileSheetScrollController = scrollController;
                        return _buildMobileExplorerSheet(
                          scrollController: scrollController,
                          collapsedHeight: collapsedSheetHeight,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EXPLORER PANEL
  // ---------------------------------------------------------------------------

  Widget _buildMobileExplorerSheet({
    required ScrollController scrollController,
    required double collapsedHeight,
  }) {
    return Material(
      color: Colors.transparent,
      elevation: 18,
      shadowColor: AppThemeColors.shadow,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        key: const ValueKey('explorer-panel'),
        decoration: BoxDecoration(
          color: AppThemeColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppThemeColors.border),
            left: BorderSide(color: AppThemeColors.border),
            right: BorderSide(color: AppThemeColors.border),
          ),
        ),
        child: CustomScrollView(
          key: const ValueKey('mobile-explorer-scroll'),
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: collapsedHeight,
                child: _buildMobileSheetHandle(),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchField(),
                    SizedBox(height: 12),
                    _buildFilterBar(),
                    if (loadingWarning != null) ...[
                      SizedBox(height: 10),
                      _buildWarning(),
                    ],
                    if (selectedRoute != null) ...[
                      SizedBox(height: 10),
                      _buildSelectedRouteCard(),
                    ],
                    SizedBox(height: selectedRoute == null ? 17 : 12),
                    _buildResultsHeader(),
                    SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      child: _buildMobileDiscoveryContent(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSheetHandle() {
    final selectedItem = selectedMapItem == null
        ? null
        : _resolvedDisplayItem(selectedMapItem!);
    final route = selectedRoute;
    final title = selectedItem != null
        ? selectedItem.title
        : route == null
        ? _exploreL10n.text('exploreTitle')
        : _asText(
            _contentFor(route)['title'],
            _exploreL10n.text('selectedRoute'),
          );
    final subtitle = selectedItem != null
        ? selectedItem.subtitle
        : route == null
        ? _exploreL10n.text('startAdventure')
        : _exploreL10n.text('currentRoute');
    final accent = selectedItem?.colour ?? _green;
    final leadingIcon = selectedItem?.icon ?? Icons.route_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('explore-sheet-handle'),
        onTap: _toggleMobileExplorerSheet,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: _textSecondary.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(height: 6),
              Row(
                key: selectedItem == null
                    ? null
                    : const ValueKey('selected-map-sheet-summary'),
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(leadingIcon, color: accent, size: 19),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _mutedText,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedItem != null && selectedItem.data != null)
                    IconButton(
                      tooltip: _exploreL10n.text('placeDetails'),
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => _showPlaceDetails(selectedItem),
                      icon: Icon(
                        Icons.info_outline_rounded,
                        color: accent,
                        size: 20,
                      ),
                    ),
                  if (selectedItem != null)
                    IconButton(
                      tooltip: _exploreL10n.text('close'),
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          selectedMapItem = null;
                        });
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: _textSecondary,
                        size: 20,
                      ),
                    )
                  else ...[
                    SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: _textSecondary,
                      size: 26,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplorerPanel({required bool desktop}) {
    return Container(
      key: const ValueKey('explorer-panel'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          desktop ? 22 : 16,
          desktop ? 22 : 15,
          desktop ? 22 : 16,
          desktop ? 20 : 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrandHeader(desktop: desktop),
            SizedBox(height: desktop ? 20 : 14),
            _buildSearchField(),
            SizedBox(height: 12),
            _buildFilterBar(),
            if (loadingWarning != null) ...[
              SizedBox(height: 10),
              _buildWarning(),
            ],
            if (selectedRoute != null) ...[
              SizedBox(height: 10),
              _buildSelectedRouteCard(),
            ],
            SizedBox(height: selectedRoute == null ? 17 : 12),
            _buildResultsHeader(),
            SizedBox(height: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                child: _buildDiscoveryContent(desktop: desktop),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader({required bool desktop}) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(
                color: _green.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/canada_bay_logo.jpg',
              semanticLabel: _exploreL10n.text('exploreTitle'),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) {
                return Icon(Icons.sailing_rounded, color: Color(0xFF0D4F7C));
              },
            ),
          ),
        ),

        SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).text('exploreAreaTitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 24,
                  height: 1.05,
                  letterSpacing: -0.7,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).text('exploreAreaSubtitle'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded, color: _green, size: 14),
              SizedBox(width: 4),
              Text(
                '${locations.length}',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          searchQuery = value;
          selectedMapItem = null;

          if (value.trim().isNotEmpty) {
            selectedFilter = 'all';
          }
        });
      },
      style: TextStyle(
        color: _textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: _exploreL10n.text('explorePrompt'),
        hintStyle: TextStyle(
          color: _textSecondary,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(Icons.search_rounded, color: _textSecondary),
        suffixIcon: searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: _exploreL10n.text('clearSearch'),
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    searchQuery = '';
                    selectedMapItem = null;
                  });
                },
                icon: Icon(Icons.close_rounded, color: _textSecondary),
              ),
        filled: true,
        fillColor: AppThemeColors.surfaceAlt,
        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppThemeColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: _green, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        key: const ValueKey('explore-filter-list'),
        scrollDirection: Axis.horizontal,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _filters.length,
        separatorBuilder: (_, _) {
          return SizedBox(width: 7);
        },
        itemBuilder: (context, index) {
          final filter = _filters[index];

          final selected = selectedFilter == filter.key;

          return ChoiceChip(
            avatar: Icon(
              filter.icon,
              size: 14,
              color: selected ? _brandInk : _textSecondary,
            ),
            label: Text(_exploreL10n.filterLabel(filter.key)),
            selected: selected,
            showCheckmark: false,
            selectedColor: _green,
            backgroundColor: AppThemeColors.surfaceAlt,
            side: BorderSide(color: selected ? _green : AppThemeColors.border),
            shape: StadiumBorder(),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            labelStyle: TextStyle(
              color: selected ? _brandInk : _textPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
            onSelected: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() {
                selectedFilter = filter.key;
                selectedMapItem = null;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildWarning() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
            size: 17,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              loadingWarning!,
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: _exploreL10n.text('retry'),
            visualDensity: VisualDensity.compact,
            onPressed: _loadExploreData,
            icon: Icon(Icons.refresh_rounded, color: _textSecondary, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedRouteCard() {
    final route = selectedRoute!;
    final content = _contentFor(route);
    final routeKey = _routeKey(route);
    final duration = _asText(content['duration'], '--');
    final distance = _asText(content['distance'], '--');
    final routeIsLoading = _loadingRouteKey == routeKey;
    final routeIsRecording = _recordingRouteKey == routeKey;
    final routeCanBeCompleted =
        widget.passport != null &&
        !routeIsLoading &&
        !routeIsRecording &&
        selectedRoutePoints.length > 1;
    final routeTitle = _asText(
      content['title'],
      _exploreL10n.text('selectedRoute'),
    );

    Widget routeIdentity() {
      return Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.route_rounded, color: _brandInk, size: 22),
          ),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _exploreL10n.text('currentRoute').toUpperCase(),
                  style: TextStyle(
                    color: _green,
                    fontSize: 8,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  routeTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '$distance  •  $duration',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _mutedText,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final completeButton = IconButton(
      tooltip: routeIsLoading
          ? _exploreL10n.text('routeLoading')
          : routeIsRecording
          ? _exploreL10n.text('routeSaving')
          : selectedRoutePoints.length < 2
          ? _exploreL10n.text('validGpxRequired')
          : widget.passport == null
          ? _exploreL10n.text('passportUnavailable')
          : _exploreL10n.text('addRouteToPassport'),
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.all(10),
      onPressed: routeCanBeCompleted ? _completeSelectedRoute : null,
      icon: routeIsLoading || routeIsRecording
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: _green, strokeWidth: 2),
            )
          : Icon(Icons.task_alt_rounded, color: _green, size: 20),
    );
    final fitButton = IconButton(
      tooltip: _exploreL10n.text('showRoute'),
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.all(10),
      onPressed: selectedRoutePoints.length > 1 ? _fitSelectedRoute : null,
      icon: Icon(
        Icons.center_focus_strong_rounded,
        color: _textSecondary,
        size: 19,
      ),
    );
    final closeButton = IconButton(
      tooltip: _exploreL10n.text('closeRoute'),
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.all(10),
      onPressed: _clearSelectedRoute,
      icon: Icon(Icons.close_rounded, color: _textSecondary, size: 19),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackActions = constraints.maxWidth < 320;
        return Container(
          key: const ValueKey('selected-route-card'),
          padding: EdgeInsets.fromLTRB(13, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppThemeColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _green.withValues(alpha: 0.30)),
          ),
          child: stackActions
              ? Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: routeIdentity(),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [completeButton, fitButton, closeButton],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: routeIdentity()),
                    completeButton,
                    fitButton,
                    closeButton,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildResultsHeader() {
    final isSearching = searchQuery.trim().isNotEmpty;
    final cyclingMode = selectedFilter == 'cycling';
    final placeMode =
        selectedFilter != 'all' && selectedFilter != 'routes' && !cyclingMode;
    final count = isSearching
        ? visibleRoutes.length + visibleLocations.length
        : placeMode
        ? visibleLocations.length
        : visibleRoutes.length;
    final title = isSearching
        ? _exploreL10n.text('searchResults')
        : placeMode
        ? _exploreL10n.text('nearby', {
            'filter': _exploreL10n.filterLabel(selectedFilter),
          })
        : cyclingMode
        ? _exploreL10n.text('cyclingRoutes')
        : selectedFilter == 'routes'
        ? _exploreL10n.text('walkingRoutes')
        : _exploreL10n.text('startAdventure');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.25,
                ),
              ),
              SizedBox(height: 2),
              Text(
                placeMode
                    ? _exploreL10n.text('tapPlace')
                    : cyclingMode
                    ? _exploreL10n.text('localRides')
                    : _exploreL10n.text('scenicWalks'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _cyan.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: _cyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryContent({required bool desktop}) {
    if (loading && routes.isEmpty && locations.isEmpty) {
      return Center(child: CircularProgressIndicator(color: _green));
    }

    if (searchQuery.trim().isNotEmpty) {
      return _buildSearchResults(desktop: desktop);
    }

    if (selectedFilter != 'all' &&
        selectedFilter != 'routes' &&
        selectedFilter != 'cycling') {
      return _buildPlaceList(desktop: desktop);
    }

    return _buildRouteList(desktop: desktop);
  }

  Widget _buildMobileDiscoveryContent() {
    if (loading && routes.isEmpty && locations.isEmpty) {
      return SizedBox(
        key: const ValueKey('mobile-discovery-loading'),
        height: 132,
        child: Center(child: CircularProgressIndicator(color: _green)),
      );
    }

    final searching = searchQuery.trim().isNotEmpty;
    final placesOnly =
        selectedFilter != 'all' &&
        selectedFilter != 'routes' &&
        selectedFilter != 'cycling';
    final entries = <Widget>[];

    if (searching) {
      for (final route in visibleRoutes) {
        entries.add(_buildRouteCard(route));
      }
      for (final location in visibleLocations) {
        entries.add(_buildPlaceCard(location));
      }
    } else if (placesOnly) {
      for (final location in visibleLocations) {
        entries.add(_buildPlaceCard(location));
      }
    } else {
      for (final route in visibleRoutes) {
        entries.add(_buildRouteCard(route));
      }
    }

    if (entries.isEmpty) {
      return SizedBox(
        key: ValueKey(
          searching ? 'mobile-search-empty' : 'mobile-discovery-empty',
        ),
        height: 132,
        child: _EmptyState(
          icon: searching
              ? Icons.search_off_rounded
              : placesOnly
              ? Icons.location_off_rounded
              : Icons.route_rounded,
          title: searching
              ? _exploreL10n.text('noMatches')
              : placesOnly
              ? _exploreL10n.text('nothingHere')
              : _exploreL10n.text('noRoutes'),
          message: searching
              ? _exploreL10n.text('tryShorterSearch')
              : placesOnly
              ? _exploreL10n.text('tryDifferentCategory')
              : _exploreL10n.text('tryAnotherSearch'),
        ),
      );
    }

    return Column(
      key: searching
          ? ValueKey('search-$searchQuery-false')
          : placesOnly
          ? ValueKey('place-list-$selectedFilter-false')
          : const ValueKey('route-list-mobile'),
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          entries[index],
          if (index != entries.length - 1) SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildRouteList({required bool desktop}) {
    if (visibleRoutes.isEmpty) {
      return _EmptyState(
        icon: Icons.route_rounded,
        title: _exploreL10n.text('noRoutes'),
        message: _exploreL10n.text('tryAnotherSearch'),
      );
    }

    if (desktop) {
      return ListView.separated(
        key: ValueKey('route-list-desktop'),
        padding: EdgeInsets.only(bottom: 4),
        itemCount: visibleRoutes.length,
        separatorBuilder: (_, _) {
          return SizedBox(height: 10);
        },
        itemBuilder: (context, index) {
          return _buildRouteCard(visibleRoutes[index]);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(268.0, constraints.maxWidth);
        return ListView.separated(
          key: ValueKey('route-list-mobile'),
          scrollDirection: Axis.horizontal,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: visibleRoutes.length,
          separatorBuilder: (_, _) {
            return SizedBox(width: 10);
          },
          itemBuilder: (context, index) {
            return SizedBox(
              width: cardWidth,
              child: _buildRouteCard(visibleRoutes[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceList({required bool desktop}) {
    if (visibleLocations.isEmpty) {
      return _EmptyState(
        icon: Icons.location_off_rounded,
        title: _exploreL10n.text('nothingHere'),
        message: _exploreL10n.text('tryDifferentCategory'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobileCardWidth = math.min(240.0, constraints.maxWidth);
        return ListView.separated(
          key: ValueKey('place-list-$selectedFilter-$desktop'),
          scrollDirection: desktop ? Axis.vertical : Axis.horizontal,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: 4),
          itemCount: visibleLocations.length,
          separatorBuilder: (_, _) =>
              SizedBox(width: desktop ? 0 : 10, height: desktop ? 9 : 0),
          itemBuilder: (context, index) {
            final card = _buildPlaceCard(visibleLocations[index]);

            return desktop
                ? card
                : SizedBox(width: mobileCardWidth, child: card);
          },
        );
      },
    );
  }

  Widget _buildSearchResults({required bool desktop}) {
    final total = visibleRoutes.length + visibleLocations.length;

    if (total == 0) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: _exploreL10n.text('noMatches'),
        message: _exploreL10n.text('tryShorterSearch'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobileCardWidth = math.min(268.0, constraints.maxWidth);
        return ListView.separated(
          key: ValueKey('search-$searchQuery-$desktop'),
          scrollDirection: desktop ? Axis.vertical : Axis.horizontal,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: 4),
          itemCount: total,
          separatorBuilder: (_, _) =>
              SizedBox(width: desktop ? 0 : 10, height: desktop ? 9 : 0),
          itemBuilder: (context, index) {
            final isRoute = index < visibleRoutes.length;
            final card = isRoute
                ? _buildRouteCard(visibleRoutes[index])
                : _buildPlaceCard(
                    visibleLocations[index - visibleRoutes.length],
                  );

            return desktop
                ? card
                : SizedBox(width: mobileCardWidth, child: card);
          },
        );
      },
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> location) {
    final item = _mapItemFromLocation(location);

    if (item == null) {
      return SizedBox.shrink();
    }

    final content = _contentFor(location);
    final description = _asText(
      content['description'],
      _exploreL10n.text('discoverLocalPlace'),
    );
    final selected = selectedMapItem?.id == item.id;

    return Material(
      color: selected
          ? item.colour.withValues(alpha: 0.13)
          : AppThemeColors.surfaceAlt,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          setState(() {
            selectedMapItem = item;
          });
          _revealMapOnMobile();
        },
        child: Container(
          constraints: BoxConstraints(minHeight: 82),
          padding: EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? item.colour.withValues(alpha: 0.65)
                  : AppThemeColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: item.colour,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: Colors.white, size: 25),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subtitle.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.colour,
                        fontSize: 8,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.near_me_rounded,
                color: selected ? item.colour : _textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final selected = _isSelectedRoute(route);
    final content = _contentFor(route);

    final title = _asText(content['title'], _exploreL10n.text('localRoute'));

    final duration = _asText(content['duration'], '--');

    final distance = _asText(content['distance'], '--');

    final difficulty = _asText(
      content['difficulty'],
      _exploreL10n.text('easy'),
    );
    final difficultyKey = _asText(route['difficulty'], 'Easy');

    final imagePath = _asText(route['image']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactCard = constraints.maxWidth < 280;
        return Material(
          color: selected ? _green.withValues(alpha: 0.09) : _panel,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 124,
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? _green : _blue.withValues(alpha: 0.14),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: compactCard ? 68 : 86,
                  height: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D4F7C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: imagePath.isEmpty
                      ? Icon(Icons.route_rounded, color: Colors.white, size: 29)
                      : Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          semanticLabel: _exploreL10n.text('photoLabel', {
                            'place': title,
                          }),
                          errorBuilder: (_, _, _) {
                            return Icon(
                              Icons.route_rounded,
                              color: Colors.white,
                              size: 29,
                            );
                          },
                        ),
                ),

                SizedBox(width: compactCard ? 9 : 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: compactCard ? 13 : 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: _green,
                              size: 17,
                            ),
                        ],
                      ),

                      SizedBox(height: 6),

                      Wrap(
                        spacing: compactCard ? 6 : 9,
                        runSpacing: 5,
                        children: [
                          _RouteDetail(
                            icon: Icons.schedule_rounded,
                            label: duration,
                          ),
                          _RouteDetail(
                            icon: Icons.navigation_outlined,
                            label: distance,
                          ),
                        ],
                      ),

                      Spacer(),

                      Row(
                        children: [
                          _DifficultyTag(
                            label: difficulty,
                            difficultyKey: difficultyKey,
                          ),
                          SizedBox(width: compactCard ? 5 : 8),
                          Expanded(
                            child: FilledButton(
                              key: ValueKey('view-route:${_routeKey(route)}'),
                              onPressed: () => _selectRoute(route),
                              style: FilledButton.styleFrom(
                                backgroundColor: _green,
                                foregroundColor: AppThemeColors.isDark
                                    ? _brandInk
                                    : Colors.white,
                                minimumSize: Size(0, 44),
                                padding: EdgeInsets.symmetric(
                                  horizontal: compactCard ? 5 : 8,
                                ),
                                visualDensity: VisualDensity.compact,
                                shape: StadiumBorder(),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_rounded
                                        : Icons.route_rounded,
                                    size: 16,
                                  ),
                                  SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      selected
                                          ? _exploreL10n.text('viewing')
                                          : _exploreL10n.text('viewRoute'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: compactCard ? 10 : 10.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MAP PANEL
  // ---------------------------------------------------------------------------

  Widget _buildMapPanel({
    required bool desktop,
    bool fullBleed = false,
    double mobileBottomInset = 0,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = desktop ? EdgeInsets.all(46) : EdgeInsets.all(22);
        final calculatedZoom = _calculateFitZoom(
          Size(constraints.maxWidth, constraints.maxHeight),
          padding,
        ).clamp(10.0, 16.0).toDouble();

        _minimumZoom = calculatedZoom;
        _fitPadding = padding;

        return Container(
          key: const ValueKey('explore-map'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: fullBleed
                ? BorderRadius.zero
                : BorderRadius.circular(desktop ? 34 : 28),
            border: fullBleed ? null : Border.all(color: AppThemeColors.border),
            boxShadow: fullBleed
                ? const []
                : [
                    BoxShadow(
                      color: AppThemeColors.shadow,
                      blurRadius: 30,
                      offset: Offset(0, 14),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    // Seed a valid camera before the responsive fit is applied
                    // so the boundary also remains safe during hot reloads.
                    initialCenter: LatLng(-33.8545, 151.1245),
                    initialZoom: calculatedZoom,
                    initialCameraFit: CameraFit.bounds(
                      bounds: _canadaBayBounds,
                      padding: padding,
                      minZoom: calculatedZoom,
                      maxZoom: calculatedZoom + 0.03,
                    ),
                    minZoom: calculatedZoom,
                    maxZoom: _maximumZoom,
                    interactionOptions: const InteractionOptions(
                      // Keep navigation natural while preventing the map and
                      // its labels from being turned away from north-up.
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    cameraConstraint: CameraConstraint.containCenter(
                      bounds: _contentCameraBounds,
                    ),
                    backgroundColor: Color(0xFFD7E3E7),
                    onTap: (_, _) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        selectedMapItem = null;
                      });
                    },
                    onPositionChanged: (camera, hasGesture) {
                      final oldGroup = _zoomLevelGroup(currentZoom);

                      currentCentre = camera.center;

                      currentZoom = camera.zoom;

                      final newGroup = _zoomLevelGroup(camera.zoom);

                      if (oldGroup != newGroup && mounted) {
                        setState(() {});
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.explorecanadabay.app',
                      maxZoom: 19,
                      tileProvider: widget.tileProvider,
                    ),

                    if (selectedRoutePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: selectedRoutePoints,
                            strokeWidth: 9,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                          Polyline(
                            points: selectedRoutePoints,
                            strokeWidth: 5,
                            color: _green,
                          ),
                        ],
                      ),

                    MarkerLayer(markers: _buildMarkers()),

                    _MapAttribution(
                      bottomInset: desktop ? 0 : mobileBottomInset,
                    ),
                  ],
                ),
              ),

              Positioned(
                top: 16,
                left: 16,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 220),
                  child: _MapBadge(
                    key: ValueKey(_asText(selectedRoute?['id'], 'all')),
                    title: selectedRoute == null
                        ? _exploreL10n.text('canadaBay')
                        : _asText(
                            _contentFor(selectedRoute!)['title'],
                            _exploreL10n.text('selectedRoute'),
                          ),
                    subtitle: selectedRoute == null
                        ? _exploreL10n.text('placesInView', {
                            'count': mapItems.length,
                          })
                        : _exploreL10n.text('routeStops', {
                            'count': selectedRouteWaypoints.length,
                          }),
                  ),
                ),
              ),

              Positioned(
                top: 16,
                right: 16,
                child: _MapControlBar(
                  onZoomIn: _zoomIn,
                  onZoomOut: _zoomOut,
                  onCentre: selectedRoutePoints.length > 1
                      ? _fitSelectedRoute
                      : _fitCanadaBay,
                  centreTooltip: selectedRoutePoints.length > 1
                      ? _exploreL10n.text('fitRoute')
                      : _exploreL10n.text('showAll'),
                ),
              ),

              if (selectedMapItem != null && desktop)
                Positioned(
                  left: 16,
                  bottom: 16,
                  width: 360,
                  child: _buildMapItemCard(
                    _resolvedDisplayItem(selectedMapItem!),
                  ),
                ),

              if (loading)
                Positioned.fill(
                  child: ColoredBox(
                    color: _navy.withValues(alpha: 0.48),
                    child: Center(child: _LoadingPill()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapItemCard(_MapItem item) {
    return Material(
      key: const ValueKey('map-place-card'),
      color: _navy.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppThemeColors.surface,
          border: Border(
            left: BorderSide(color: item.colour, width: 4),
            top: BorderSide(color: item.colour.withValues(alpha: 0.34)),
            bottom: BorderSide(color: item.colour.withValues(alpha: 0.34)),
          ),
          boxShadow: [
            BoxShadow(
              color: AppThemeColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.colour,
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: Colors.white, size: 22),
            ),

            SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    item.subtitle.toUpperCase(),
                    style: TextStyle(
                      color: item.colour,
                      fontSize: 8.5,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            if (item.data != null)
              IconButton(
                tooltip: _exploreL10n.text('placeDetails'),
                onPressed: () => _showPlaceDetails(item),
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: item.colour,
                  size: 20,
                ),
              ),
            IconButton(
              tooltip: _exploreL10n.text('close'),
              onPressed: () {
                setState(() {
                  selectedMapItem = null;
                });
              },
              icon: Icon(Icons.close_rounded, color: _textSecondary, size: 19),
            ),
          ],
        ),
      ),
    );
  }

  _MapItem _resolvedDisplayItem(_MapItem item) {
    final data = item.data;
    if (data == null) return item;
    return _mapItemFromLocation(data) ?? item;
  }

  void _showPlaceDetails(
    _MapItem item, {
    List<_MapItem> discoveries = const <_MapItem>[],
  }) {
    final data = item.data;
    if (data == null) return;
    final content = _contentFor(data);

    final description = _asText(
      content['description'],
      _exploreL10n.text('discoverPlace'),
    );
    final learningPrompt = _asText(content['learningPrompt']).trim();
    final sourceLabel = _asText(content['sourceLabel']).trim();
    final officialUrl = _asText(data['officialUrl']).trim();
    final imagePath = _asText(data['image']).trim();
    final address = _asText(content['address']).trim();
    final accessibility = _asText(content['accessibility']).trim();
    final highlightsSource = content['highlights'];
    final highlights = highlightsSource is List
        ? highlightsSource
              .map((highlight) => _asText(highlight).trim())
              .where((highlight) => highlight.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              key: const ValueKey('place-details-sheet'),
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
              ),
              margin: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: item.colour.withValues(alpha: 0.4)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: item.colour.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(item.icon, color: item.colour),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                  color: item.colour,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: _exploreL10n.text('close'),
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(
                            Icons.close_rounded,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (imagePath.isNotEmpty) ...[
                      SizedBox(height: 16),
                      _PlaceHeroImage(
                        imagePath: imagePath,
                        semanticLabel: _exploreL10n.text('photoLabel', {
                          'place': item.title,
                        }),
                        accent: item.colour,
                      ),
                    ],
                    SizedBox(height: 18),
                    Text(
                      description,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      SizedBox(height: 14),
                      _PlaceDetailRow(
                        icon: Icons.location_on_rounded,
                        label: address,
                        colour: item.colour,
                      ),
                    ],
                    if (accessibility.isNotEmpty) ...[
                      SizedBox(height: 10),
                      _PlaceDetailRow(
                        icon: Icons.accessible_rounded,
                        label: accessibility,
                        colour: item.colour,
                      ),
                    ],
                    if (learningPrompt.isNotEmpty) ...[
                      SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: item.colour.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              color: item.colour,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                learningPrompt,
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (highlights.isNotEmpty) ...[
                      SizedBox(height: 20),
                      Text(
                        _exploreL10n.text('atThisPlace'),
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 10),
                      for (final highlight in highlights)
                        Padding(
                          padding: EdgeInsets.only(bottom: 9),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: item.colour.withValues(alpha: 0.13),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: item.colour,
                                  size: 14,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  highlight,
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (discoveries.isNotEmpty) ...[
                      SizedBox(height: 20),
                      Text(
                        _exploreL10n.text('foundHere'),
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 10),
                      for (final discovery in discoveries)
                        _PlaceDiscoveryCard(
                          item: discovery,
                          onTap: discovery.data == null
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  _showPlaceDetails(discovery);
                                },
                        ),
                    ],
                    if (officialUrl.isNotEmpty) ...[
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final opened = await const ExternalLinkService()
                                .open(officialUrl);
                            if (!mounted || opened) return;
                            await Clipboard.setData(
                              ClipboardData(text: officialUrl),
                            );
                            if (mounted) {
                              _showMessage(_exploreL10n.text('linkCopied'));
                            }
                          },
                          icon: Icon(Icons.open_in_new_rounded),
                          label: Text(
                            sourceLabel.isEmpty
                                ? _exploreL10n.text('openOfficial')
                                : _exploreL10n.text('officialSource', {
                                    'source': sourceLabel,
                                  }),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

// =============================================================================
// SUPPORTING WIDGETS
// =============================================================================

class _PlaceHeroImage extends StatelessWidget {
  const _PlaceHeroImage({
    required this.imagePath,
    required this.semanticLabel,
    required this.accent,
  });

  final String imagePath;
  final String semanticLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    Widget errorBuilder(
      BuildContext context,
      Object error,
      StackTrace? stackTrace,
    ) {
      return ColoredBox(
        color: accent.withValues(alpha: 0.1),
        child: Center(
          child: Icon(Icons.image_not_supported_rounded, color: accent),
        ),
      );
    }

    final image =
        imagePath.startsWith('https://') || imagePath.startsWith('http://')
        ? Image.network(
            imagePath,
            fit: BoxFit.cover,
            semanticLabel: semanticLabel,
            errorBuilder: errorBuilder,
          )
        : Image.asset(
            imagePath,
            fit: BoxFit.cover,
            semanticLabel: semanticLabel,
            errorBuilder: errorBuilder,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(aspectRatio: 16 / 7, child: image),
    );
  }
}

class _PlaceDetailRow extends StatelessWidget {
  const _PlaceDetailRow({
    required this.icon,
    required this.label,
    required this.colour,
  });

  final IconData icon;
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colour.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: colour, size: 18),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text(
              label,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceDiscoveryCard extends StatelessWidget {
  const _PlaceDiscoveryCard({required this.item, this.onTap});

  final _MapItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = ExploreLocalizations.of(context);
    final data = item.data;
    final content = data == null ? null : l10n.contentFor(data);
    final description = content?['description']?.toString().trim() ?? '';
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Material(
        color: item.colour.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: item.colour.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.colour, size: 21),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        description.isEmpty ? item.subtitle : description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: item.colour,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreFilter {
  final String key;
  final IconData icon;

  _ExploreFilter({required this.key, required this.icon});
}

class _RouteDetail extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RouteDetail({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _textSecondary, size: 12),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DifficultyTag extends StatelessWidget {
  final String label;
  final String difficultyKey;

  const _DifficultyTag({required this.label, required this.difficultyKey});

  @override
  Widget build(BuildContext context) {
    final value = difficultyKey.toLowerCase();

    final Color colour;

    if (value.contains('hard')) {
      colour = Colors.redAccent;
    } else if (value.contains('moderate') || value.contains('medium')) {
      colour = Colors.orangeAccent;
    } else {
      colour = _green;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colour,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppThemeColors.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _textSecondary, size: 34),
          SizedBox(height: 9),
          Text(
            title,
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSecondary, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MapBadge({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final compass = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.explore_rounded, color: _green, size: 18),
    );

    return Semantics(
      key: const ValueKey('map-context-badge'),
      label: '$title. $subtitle',
      child: Material(
        color: AppThemeColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: BoxConstraints(maxWidth: 240, minHeight: 52),
          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppThemeColors.border),
            boxShadow: [
              BoxShadow(
                color: AppThemeColors.shadow,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              compass,
              SizedBox(width: 9),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution({this.bottomInset = 0});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final l10n = ExploreLocalizations.of(context);
    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        minimum: EdgeInsets.fromLTRB(4, 4, 4, 4 + bottomInset),
        child: Container(
          key: const ValueKey('map-attribution'),
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Color(0xDDF7FAFB),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            l10n.text('mapAttribution'),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: Color(0xFF294653),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapControlBar extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCentre;
  final String centreTooltip;

  const _MapControlBar({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCentre,
    required this.centreTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = ExploreLocalizations.of(context);
    return Material(
      key: const ValueKey('map-control-bar'),
      color: _navy.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppThemeColors.border),
          boxShadow: [
            BoxShadow(
              color: AppThemeColors.shadow,
              blurRadius: 15,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MapControlButton(
              icon: Icons.add_rounded,
              tooltip: l10n.text('zoomIn'),
              onTap: onZoomIn,
            ),
            _MapDivider(),
            _MapControlButton(
              icon: Icons.remove_rounded,
              tooltip: l10n.text('zoomOut'),
              onTap: onZoomOut,
            ),
            _MapDivider(),
            _MapControlButton(
              icon: Icons.fit_screen_rounded,
              tooltip: centreTooltip,
              onTap: onCentre,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: _textSecondary, size: 21),
        ),
      ),
    );
  }
}

class _MapDivider extends StatelessWidget {
  const _MapDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: AppThemeColors.border);
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) {
    final l10n = ExploreLocalizations.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _navy.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: _green, strokeWidth: 2.4),
          ),
          SizedBox(width: 11),
          Flexible(
            child: Text(
              l10n.text('findingAdventures'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GpxWaypoint {
  final String name;
  final String type;
  final LatLng point;
  final String description;

  _GpxWaypoint({
    required this.name,
    required this.type,
    required this.point,
    required this.description,
  });
}

enum _MapItemType { location, route, waypoint, start, finish }

enum _PlaceKind {
  food,
  park,
  gym,
  library,
  community,
  biodiversity,
  attraction,
  toilet,
  generic,
}

class _MapItem {
  final String id;
  final String title;
  final String subtitle;
  final LatLng point;
  final IconData icon;
  final Color colour;
  final _MapItemType type;
  final Map<String, dynamic>? route;
  final Map<String, dynamic>? data;

  _MapItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.point,
    required this.icon,
    required this.colour,
    required this.type,
    this.route,
    this.data,
  });
}
