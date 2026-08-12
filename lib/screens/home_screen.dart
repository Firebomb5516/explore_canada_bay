import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/community_services_localizations.dart';
import '../l10n/explore_localizations.dart';
import '../l10n/journey_activity_localizations.dart';
import '../l10n/journey_localizations.dart';
import '../models/community_item.dart';
import '../models/community_challenge.dart';
import '../models/environmental_story.dart';
import '../models/local_service_item.dart';
import '../models/newcomer_journey.dart';
import '../models/passport.dart';
import '../models/settlement_profile.dart';
import '../services/community_repository.dart';
import '../services/environment_repository.dart';
import '../services/external_link_service.dart';
import '../services/location_service.dart';
import '../services/local_services_repository.dart';
import '../services/newcomer_journey_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/localized_text.dart';

const _homeBlue = Color(0xFF0D4F7C);
Color get _homeGreen => AppThemeColors.accentGreen;
Color get _homeDark => AppThemeColors.backgroundAlt;
Color get _homeCard => AppThemeColors.surface;
Color get _homeCardLight => AppThemeColors.surfaceAlt;
Color get _homeText => AppThemeColors.text;
Color get _homeMuted => AppThemeColors.muted;
const _homeAccent = Color(0xFF2179C8);
const _homeLogoAsset = 'assets/images/canada_bay_logo.jpg';

class HomeScreen extends StatefulWidget {
  final PassportController passport;
  final CommunityChallengeController communityChallenge;
  final VoidCallback? onOpenScan;
  final VoidCallback? onOpenExplore;
  final VoidCallback? onOpenRoutes;
  final ValueChanged<Map<String, dynamic>>? onOpenPlace;
  final ValueChanged<Map<String, dynamic>>? onStartRoute;
  final VoidCallback? onOpenPassport;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenCommunity;
  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenJourney;
  final String explorerName;
  final String residentType;
  final Set<String> interests;
  final SettlementProfileController settlement;

  const HomeScreen({
    super.key,
    required this.passport,
    required this.communityChallenge,
    this.onOpenScan,
    this.onOpenExplore,
    this.onOpenRoutes,
    this.onOpenPlace,
    this.onStartRoute,
    this.onOpenPassport,
    this.onOpenProfile,
    this.onOpenCommunity,
    this.onOpenServices,
    this.onOpenJourney,
    this.explorerName = 'Explorer',
    this.residentType = 'New resident',
    this.interests = const <String>{},
    required this.settlement,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> routes = [];
  List<Map<String, dynamic>> locations = [];
  List<EnvironmentalStory> environmentalStories = [];
  List<CommunityItem> communityItems = [];
  List<LocalServiceItem> essentialServices = [];
  CommunityItem? featuredCommunity;
  LocalPosition? _currentPosition;
  bool _locating = false;
  NewcomerJourneyCatalog? _journeyCatalog;

  Map<String, dynamic>? featuredRoute;

  final Set<String> savedRoutes = {};
  final List<_HomeActivity> activities = [];

  bool loading = true;
  String? loadingWarning;

  int _featuredRouteIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.passport.addListener(_handlePassportChanged);
    widget.settlement.addListener(_handlePassportChanged);
    _loadHomeData();
    _loadJourneyCatalog();
  }

  Future<void> _loadJourneyCatalog() async {
    try {
      final catalog = await const NewcomerJourneyRepository().loadCatalog();
      if (mounted) setState(() => _journeyCatalog = catalog);
    } on Object catch (error) {
      debugPrint('Home journey summary unavailable: $error');
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.passport != widget.passport) {
      oldWidget.passport.removeListener(_handlePassportChanged);
      widget.passport.addListener(_handlePassportChanged);
    }
    if (oldWidget.settlement != widget.settlement) {
      oldWidget.settlement.removeListener(_handlePassportChanged);
      widget.settlement.addListener(_handlePassportChanged);
    }
    if (oldWidget.residentType != widget.residentType ||
        oldWidget.interests != widget.interests) {
      _featuredRouteIndex = _preferredRouteIndex(routes);
      featuredRoute = routes.isEmpty ? null : routes[_featuredRouteIndex];
      featuredCommunity = _preferredCommunityItem(communityItems);
    }
  }

  void _handlePassportChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.passport.removeListener(_handlePassportChanged);
    widget.settlement.removeListener(_handlePassportChanged);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadJsonList(
    List<String> paths, {
    bool optional = false,
  }) async {
    Object? lastError;

    for (final path in paths) {
      try {
        final source = await rootBundle.loadString(path);
        final decoded = json.decode(source);

        if (decoded is! List) {
          throw FormatException('$path must contain a JSON list.');
        }

        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      } catch (error) {
        lastError = error;
      }
    }

    if (optional) {
      return [];
    }

    throw Exception('Could not load ${paths.join(' or ')}.\n$lastError');
  }

  Future<void> _loadHomeData() async {
    if (mounted) {
      setState(() {
        loading = true;
        loadingWarning = null;
      });
    }

    final warnings = <String>[];

    var loadedRoutes = <Map<String, dynamic>>[];
    var loadedLocations = <Map<String, dynamic>>[];
    var loadedEnvironmentalStories = <EnvironmentalStory>[];
    var loadedCommunityItems = <CommunityItem>[];
    var loadedEssentialServices = <LocalServiceItem>[];

    try {
      loadedRoutes = await _loadJsonList([
        'assets/data/routes.json',
        'assets/routes.json',
      ]);
    } catch (error) {
      debugPrint('Home routes error: $error');
      warnings.add('routes.json');
    }

    try {
      loadedLocations = await _loadJsonList([
        'assets/data/locations.json',
        'assets/locations.json',
      ]);
    } catch (error) {
      debugPrint('Home locations error: $error');
      warnings.add('locations.json');
    }

    for (final asset in const [
      'assets/data/food.json',
      'assets/data/biodiversity.json',
    ]) {
      try {
        loadedLocations = _mergePlaces([
          ...loadedLocations,
          ...await _loadJsonList([asset]),
        ]);
      } catch (error) {
        debugPrint('Home nearby content error ($asset): $error');
        warnings.add(asset.split('/').last);
      }
    }

    try {
      loadedEnvironmentalStories = await const EnvironmentRepository()
          .loadStories();
    } catch (error) {
      debugPrint('Home environment error: $error');
      warnings.add('environment.json');
    }

    try {
      loadedCommunityItems = await const CommunityRepository().load();
    } catch (error) {
      debugPrint('Home community error: $error');
      warnings.add('community.json');
    }

    try {
      final catalogue = await const LocalServicesRepository().loadCatalog();
      loadedEssentialServices = catalogue.services
          .where((service) => service.isEssential)
          .toList(growable: false);
    } catch (error) {
      debugPrint('Home local services error: $error');
      warnings.add('local_services.json');
    }

    if (!mounted) return;

    setState(() {
      routes = loadedRoutes;
      locations = loadedLocations;
      environmentalStories = loadedEnvironmentalStories;
      communityItems = loadedCommunityItems;
      essentialServices = loadedEssentialServices;

      _featuredRouteIndex = _preferredRouteIndex(routes);
      featuredRoute = routes.isEmpty ? null : routes[_featuredRouteIndex];
      featuredCommunity = _preferredCommunityItem(loadedCommunityItems);

      loadingWarning = warnings.isEmpty
          ? null
          : '${warnings.join(' and ')} could not be loaded. '
                'Check your asset paths and pubspec.yaml.';

      loading = false;
    });
  }

  int _preferredRouteIndex(List<Map<String, dynamic>> availableRoutes) {
    if (availableRoutes.isEmpty) return 0;

    final wantsOutdoors = widget.interests.any(
      (interest) => interest.toLowerCase() == 'outdoors',
    );
    if (wantsOutdoors) {
      final cyclingIndex = availableRoutes.indexWhere(
        (route) => _text(route['category']).trim().toLowerCase() == 'cycling',
      );
      if (cyclingIndex >= 0) return cyclingIndex;
    }

    final compactRouteIndex = availableRoutes.indexWhere(
      (route) => _text(route['id']) == 'rhodes_bicentenial',
    );
    if (widget.residentType == 'Family' && compactRouteIndex >= 0) {
      return compactRouteIndex;
    }

    return 0;
  }

  CommunityItem? _preferredCommunityItem(List<CommunityItem> items) {
    if (items.isEmpty) return null;
    final featured = items.where((item) => item.featured).toList();
    final candidates = featured.isEmpty ? items : featured;
    final interests = widget.interests
        .map((interest) => interest.toLowerCase())
        .toSet();

    final preferredCategories = <CommunityCategory>[
      if (interests.contains('environment')) CommunityCategory.bushcare,
      if (interests.contains('local food')) CommunityCategory.festivals,
      if (interests.contains('outdoors')) CommunityCategory.cycling,
      if (interests.contains('community')) CommunityCategory.events,
      if (interests.contains('local services')) CommunityCategory.library,
    ];

    for (final category in preferredCategories) {
      for (final item in candidates) {
        if (item.category == category) return item;
      }
    }
    return candidates.first;
  }

  List<Map<String, dynamic>> _mergePlaces(List<Map<String, dynamic>> places) {
    final byName = <String, Map<String, dynamic>>{};
    for (final place in places) {
      final name = _text(place['name'], _text(place['title'])).trim();
      if (name.isEmpty) continue;
      byName.putIfAbsent(name.toLowerCase(), () => place);
    }
    return byName.values.toList(growable: false);
  }

  String _text(dynamic value, [String fallback = '']) {
    return value?.toString() ?? fallback;
  }

  Map<String, dynamic> _localizedExploreContent(Map<String, dynamic> item) =>
      ExploreLocalizations.of(context).contentFor(item);

  String _routeKey(Map<String, dynamic> route) {
    return _text(route['id'], _text(route['title'], 'route-${route.hashCode}'));
  }

  double get levelProgress {
    return widget.passport.levelProgress;
  }

  bool _hasScannedLocation(Map<String, dynamic> location) {
    final name = _text(location['name']).trim().toLowerCase();
    if (name.isEmpty) return false;
    return widget.passport.scanHistory.any(
      (scan) => scan.placeName.trim().toLowerCase() == name,
    );
  }

  double get passportProgress {
    final badges = widget.passport.badges;
    if (badges.isEmpty) {
      return 0;
    }

    final totalProgress = badges.fold<int>(
      0,
      (total, badge) => total + badge.progress,
    );
    final totalTargets = badges.fold<int>(
      0,
      (total, badge) => total + badge.target,
    );
    return (totalProgress / totalTargets).clamp(0.0, 1.0);
  }

  int get activityStreak {
    final activeDays = widget.passport.scanHistory
        .map((record) => DateUtils.dateOnly(record.scannedAt.toLocal()))
        .toSet();
    if (activeDays.isEmpty) return 0;

    final today = DateUtils.dateOnly(DateTime.now());
    var cursor = activeDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var total = 0;
    while (activeDays.contains(cursor)) {
      total++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return total;
  }

  List<_HomeActivity> get recentActivities {
    final strings = AppLocalizations.of(context);
    final journeyCopy = JourneyActivityLocalizations.of(context);
    final passportActivities = widget.passport.scanHistory.map((record) {
      final localized = journeyCopy.resolve(
        record,
        settlement: widget.settlement,
      );
      final reward = record.xpAwarded == 0
          ? strings.literal('Stamp updated')
          : '+${record.xpAwarded} XP';
      return _HomeActivity(
        icon: record.badgeId == null
            ? Icons.explore_rounded
            : Icons.workspace_premium_rounded,
        colour: _homeGreen,
        title: localized.placeName,
        subtitle: '$reward · Community Passport',
      );
    });
    return <_HomeActivity>[...activities, ...passportActivities];
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _openExplore() {
    if (widget.onOpenExplore != null) {
      widget.onOpenExplore!();
      return;
    }

    _showMessage('Explore is not connected yet.');
  }

  void _openRoutes() {
    if (widget.onOpenRoutes != null) {
      widget.onOpenRoutes!();
      return;
    }

    _openExplore();
  }

  void _openPlace(Map<String, dynamic> place) {
    if (widget.onOpenPlace != null) {
      widget.onOpenPlace!(place);
      return;
    }
    _openExplore();
  }

  void _openScanner() {
    if (widget.onOpenScan != null) {
      widget.onOpenScan!();
      return;
    }

    _showMessage('The scanner is not connected yet.');
  }

  void _openProfile() {
    if (widget.onOpenProfile != null) {
      widget.onOpenProfile!();
      return;
    }

    _showPassportSheet();
  }

  void _openPassport() {
    if (widget.onOpenPassport != null) {
      widget.onOpenPassport!();
      return;
    }

    _showPassportSheet();
  }

  void _openCommunity() {
    if (widget.onOpenCommunity != null) {
      widget.onOpenCommunity!();
      return;
    }
    _showMessage('Community is not connected yet.');
  }

  void _openServices() {
    if (widget.onOpenServices != null) {
      widget.onOpenServices!();
      return;
    }
    _showMessage('Local Services is not connected yet.');
  }

  Future<void> _openOfficialLink(String url) async {
    final opened = await const ExternalLinkService().open(url);
    if (!mounted || opened) return;

    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      _showMessage(
        'This device could not open the link, so it was copied instead.',
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      final position = await const LocationService().getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _locating = false;
      });
      _showMessage('Places are now sorted by distance from you.');
    } on LocationAccessException catch (error) {
      if (!mounted) return;
      setState(() => _locating = false);
      _showMessage(error.message);
    } on Object catch (error) {
      debugPrint('Home location error: $error');
      if (!mounted) return;
      setState(() => _locating = false);
      _showMessage(
        'Your location is unavailable right now. You can still browse every place.',
      );
    }
  }

  double? _coordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double? _distanceTo(Map<String, dynamic> place) {
    final position = _currentPosition;
    final latitude = _coordinate(place['lat']);
    final longitude = _coordinate(place['lng']);
    if (position == null || latitude == null || longitude == null) {
      return null;
    }
    return const LocationService().distanceMetres(
      position,
      latitude: latitude,
      longitude: longitude,
    );
  }

  String? _distanceLabel(Map<String, dynamic> place) {
    final metres = _distanceTo(place);
    if (metres == null) return null;
    final source = metres < 1000
        ? '${metres.round()} m away'
        : '${(metres / 1000).toStringAsFixed(1)} km away';
    return AppLocalizations.of(context).literal(source);
  }

  String _typeAndDistanceLabel(Map<String, dynamic> place) {
    final type = _typeLabel(place['type']);
    final distance = _distanceLabel(place);
    return distance == null ? type : '$type · $distance';
  }

  void _toggleSavedRoute(Map<String, dynamic> route) {
    final key = _routeKey(route);

    final content = _localizedExploreContent(route);
    final title = _text(content['title'], 'Route');

    final alreadySaved = savedRoutes.contains(key);

    setState(() {
      if (alreadySaved) {
        savedRoutes.remove(key);
      } else {
        savedRoutes.add(key);

        activities.insert(
          0,
          _HomeActivity(
            icon: Icons.bookmark_rounded,
            colour: _homeGreen,
            title: '$title saved',
            subtitle: 'Added to your saved routes',
          ),
        );
      }
    });

    _showMessage(
      alreadySaved ? '$title removed from saved routes.' : '$title saved.',
    );
  }

  void _startRoute(Map<String, dynamic> route) {
    final content = _localizedExploreContent(route);
    final title = _text(content['title'], 'Route');

    setState(() {
      activities.insert(
        0,
        _HomeActivity(
          icon: Icons.route_rounded,
          colour: _homeGreen,
          title: '$title opened',
          subtitle: 'Route sent to the Explore map',
        ),
      );
    });

    if (widget.onStartRoute != null) {
      widget.onStartRoute!(route);
      return;
    }

    _openExplore();
  }

  void _showAnotherRoute() {
    if (routes.length < 2) {
      _showMessage('There are no other routes to show yet.');
      return;
    }

    setState(() {
      _featuredRouteIndex = (_featuredRouteIndex + 1) % routes.length;
      featuredRoute = routes[_featuredRouteIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _homeDark,
      body: ColoredBox(
        color: AppThemeColors.background,
        child: SafeArea(
          child: loading
              ? _HomeLoadingView()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 980;

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        desktop ? 30 : 16,
                        desktop ? 24 : 16,
                        desktop ? 30 : 16,
                        28,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 1380),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(desktop),

                              if (loadingWarning != null) ...[
                                SizedBox(height: 14),
                                _buildWarning(),
                              ],

                              SizedBox(height: 18),
                              _buildNextStep(),
                              SizedBox(height: 12),
                              _buildCommunityChallenge(),
                              SizedBox(height: 22),

                              desktop
                                  ? _buildDesktopLayout()
                                  : _buildMobileLayout(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildCommunityChallenge() {
    return AnimatedBuilder(
      animation: widget.communityChallenge,
      builder: (context, _) {
        final controller = widget.communityChallenge;
        final challenge = controller.snapshot;
        final strings = AppLocalizations.of(context);
        final status = !controller.cloudAvailable
            ? strings.literal('Connect Supabase to activate shared progress')
            : !controller.isSignedIn
            ? strings.literal('Sign in to add your activities')
            : challenge.completed
            ? strings.literal('Community reward unlocked!')
            : strings.literal('Your Passport activities count automatically');

        return Material(
          color: _homeGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            onTap: _openPassport,
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _homeGreen,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.groups_2_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.literal('COMMUNITY CHALLENGE'),
                              style: TextStyle(
                                color: _homeGreen,
                                fontSize: 9,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              strings.literal(challenge.title),
                              style: TextStyle(
                                color: _homeText,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (controller.loading)
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(Icons.arrow_forward_rounded, color: _homeGreen),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${challenge.communityPoints} / ${challenge.targetPoints} ${strings.literal('community points')}',
                          style: TextStyle(
                            color: _homeText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${(challenge.progress * 100).round()}%',
                        style: TextStyle(
                          color: _homeGreen,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: challenge.progress,
                      minHeight: 9,
                      backgroundColor: AppThemeColors.surfaceAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(_homeGreen),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: _homeGreen,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          status,
                          style: TextStyle(
                            color: _homeMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (controller.isSignedIn)
                        Text(
                          '+${challenge.personalPoints} ${strings.literal('yours')}',
                          style: TextStyle(
                            color: _homeGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNextStep() {
    final journeyCopy = JourneyLocalizations.of(context);
    NewcomerJourneyTask? nextTask;
    for (final task
        in _journeyCatalog?.tasks ?? const <NewcomerJourneyTask>[]) {
      if (!_isHomeJourneyTaskComplete(task)) {
        nextTask = task;
        break;
      }
    }
    final ({IconData icon, String eyebrow, String title, String body}) content;
    if (nextTask != null) {
      content = (
        icon: _homeJourneyIcon(nextTask.kind),
        eyebrow: 'YOUR NEXT STEP',
        title: journeyCopy.title(nextTask),
        body: journeyCopy.summary(nextTask),
      );
    } else {
      content = (
        icon: Icons.verified_rounded,
        eyebrow: 'JOURNEY COMPLETE',
        title: journeyCopy.ui('journeyCompleteTitle'),
        body: journeyCopy.ui('journeyCompleteBody'),
      );
    }
    return Material(
      color: _homeBlue,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: widget.onOpenJourney,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(content.icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.eyebrow,
                      style: const TextStyle(
                        color: Color(0xFF8FF5D1),
                        fontSize: 9,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      content.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  bool _isHomeJourneyTaskComplete(NewcomerJourneyTask task) {
    if (task.id == 'find-bin-day') return widget.settlement.hasBinDay;
    if (task.id == 'discover-library') return widget.settlement.hasLibraryCard;
    if (task.id == 'plan-first-trip') {
      return widget.settlement.hasTransportShortcut;
    }
    if (task.canSelfComplete) {
      return widget.passport.hasActivity(task.activityId);
    }
    return widget.passport.badgeProgress(task.badgeId) > 0;
  }

  IconData _homeJourneyIcon(JourneyTaskKind kind) => switch (kind) {
    JourneyTaskKind.learn => Icons.menu_book_rounded,
    JourneyTaskKind.civic => Icons.account_balance_rounded,
    JourneyTaskKind.explore => Icons.explore_rounded,
    JourneyTaskKind.community => Icons.groups_rounded,
  };

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 11,
          child: Column(
            children: [
              _buildHero(desktop: true),
              SizedBox(height: 20),
              _buildActionsPanel(),
              SizedBox(height: 20),
              _buildCivicEssentialsPanel(),
              SizedBox(height: 20),
              _buildNearbyPanel(),
              SizedBox(height: 20),
              _buildEnvironmentalPanel(),
            ],
          ),
        ),
        SizedBox(width: 22),
        Expanded(
          flex: 9,
          child: Column(
            children: [
              _buildSuggestedRoute(desktop: true),
              SizedBox(height: 20),
              _buildCommunityPanel(),
              SizedBox(height: 20),
              _buildProgressPanel(),
              SizedBox(height: 20),
              _buildActivityPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildMobileHero(),
        SizedBox(height: 14),
        _buildSuggestedRoute(desktop: false),
      ],
    );
  }

  Widget _buildMobileHero() {
    final strings = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppThemeColors.border),
        boxShadow: [
          BoxShadow(
            color: AppThemeColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.message('homeWelcome', {'name': widget.explorerName}),
            style: TextStyle(
              color: _homeText,
              fontSize: 25,
              height: 1.05,
              letterSpacing: -0.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            strings.text('homePrompt'),
            style: TextStyle(
              color: _homeMuted,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _HomeActionTile(
                  icon: Icons.map_outlined,
                  label: strings.text('openMap'),
                  colour: _homeAccent,
                  onTap: _openExplore,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HomeActionTile(
                  icon: Icons.qr_code_scanner_rounded,
                  label: strings.text('scan'),
                  colour: _homeGreen,
                  onTap: _openScanner,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HomeActionTile(
                  icon: Icons.account_balance_outlined,
                  label: strings.text('services'),
                  colour: _homeBlue,
                  onTap: _openServices,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool desktop) {
    return Row(
      children: [
        Container(
          width: desktop ? 64 : 58,
          height: desktop ? 64 : 58,
          padding: EdgeInsets.all(desktop ? 7 : 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(desktop ? 21 : 17),
            boxShadow: [
              BoxShadow(
                color: AppThemeColors.shadow,
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(desktop ? 15 : 12),
            child: Image.asset(
              _homeLogoAsset,
              fit: BoxFit.cover,
              semanticLabel: AppLocalizations.of(
                context,
              ).literal('City of Canada Bay logo'),
              errorBuilder: (_, _, _) {
                return Icon(
                  Icons.sailing_rounded,
                  color: _homeBlue,
                  size: desktop ? 34 : 28,
                );
              },
            ),
          ),
        ),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Explore ',
                      style: TextStyle(
                        color: _homeText,
                        fontSize: desktop ? 27 : 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: 'Canada ',
                      style: TextStyle(
                        color: _homeGreen,
                        fontSize: desktop ? 27 : 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: 'Bay',
                      style: TextStyle(
                        color: _homeAccent,
                        fontSize: desktop ? 27 : 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'LOCAL EXPLORATION · CIVIC INFORMATION · COMMUNITY CONNECTION · '
                'ENVIRONMENTAL LEARNING · INTERACTIVE ENGAGEMENT',
                maxLines: desktop ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _homeMuted,
                  fontSize: desktop ? 10 : 7.5,
                  letterSpacing: desktop ? 1.2 : 0.65,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        _HomeRoundButton(
          icon: Icons.account_circle_outlined,
          tooltip: AppLocalizations.of(context).text('profile'),
          onTap: _openProfile,
        ),
      ],
    );
  }

  Widget _buildWarning() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              loadingWarning!,
              style: TextStyle(
                color: _homeText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).literal('Retry'),
            onPressed: _loadHomeData,
            icon: Icon(Icons.refresh_rounded, color: _homeMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildHero({required bool desktop}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(desktop ? 30 : 21),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -15,
            child: Icon(
              Icons.explore_outlined,
              size: desktop ? 175 : 118,
              color: Colors.white.withValues(alpha: 0.045),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeMiniLabel(
                icon: Icons.location_searching,
                label: AppLocalizations.of(
                  context,
                ).literal(widget.residentType).toUpperCase(),
              ),
              SizedBox(height: 18),
              Text(
                'Welcome, ${widget.explorerName}',
                style: TextStyle(
                  color: _homeText,
                  fontSize: desktop ? 42 : 29,
                  height: 1.04,
                  letterSpacing: -0.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 11),
              Text(
                'Find the services, community activities and local places that help Canada Bay feel like home.',
                style: TextStyle(
                  color: _homeMuted,
                  fontSize: desktop ? 17 : 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Level ${widget.passport.level} progress',
                      style: TextStyle(
                        color: _homeMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.passport.totalXp} XP · '
                    '${widget.passport.xpToNextLevel} to next',
                    style: TextStyle(
                      color: _homeGreen,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: levelProgress,
                  minHeight: 9,
                  backgroundColor: AppThemeColors.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(_homeGreen),
                ),
              ),
              SizedBox(height: 20),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _HomePillButton(
                    icon: Icons.explore_rounded,
                    label: 'Explore Map',
                    filled: true,
                    onTap: _openExplore,
                  ),
                  _HomePillButton(
                    icon: Icons.route_rounded,
                    label: 'Browse Routes',
                    onTap: _openRoutes,
                  ),
                  _HomeStatusPill(
                    icon: Icons.local_fire_department_rounded,
                    label: activityStreak == 0
                        ? 'Start a discovery streak'
                        : '$activityStreak day streak',
                    colour: Colors.orangeAccent,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsPanel() {
    return _HomePanel(
      icon: Icons.grid_view_rounded,
      title: 'Start Exploring',
      subtitle: 'Your main tools in one place',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gap = constraints.maxWidth < 420 ? 7.0 : 10.0;

          final columns = constraints.maxWidth >= 520 ? 3 : 2;
          final tileWidth =
              (constraints.maxWidth - gap * (columns - 1)) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: tileWidth,
                child: _HomeActionTile(
                  icon: Icons.map_outlined,
                  label: 'Map',
                  colour: _homeAccent,
                  onTap: _openExplore,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _HomeActionTile(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan',
                  colour: _homeGreen,
                  onTap: _openScanner,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _HomeActionTile(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Passport',
                  colour: Colors.orangeAccent,
                  onTap: _openPassport,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _HomeActionTile(
                  icon: Icons.groups_rounded,
                  label: 'Community',
                  colour: Color(0xFF8B78E6),
                  onTap: _openCommunity,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _HomeActionTile(
                  icon: Icons.account_balance_rounded,
                  label: 'Civic help',
                  colour: Color(0xFF48A9C5),
                  onTap: _openServices,
                ),
              ),
              SizedBox(
                width: tileWidth,
                child: _HomeActionTile(
                  icon: Icons.tune_rounded,
                  label: 'Preferences',
                  colour: Color(0xFF64C8DC),
                  onTap: _openProfile,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCivicEssentialsPanel() {
    const priorityIds = [
      'bin-collection',
      'report-council-issue',
      'public-transport',
      'emergency-help',
    ];
    final byId = {for (final service in essentialServices) service.id: service};
    final languageCode = Localizations.localeOf(context).languageCode;
    final services = priorityIds
        .map((id) => byId[id])
        .whereType<LocalServiceItem>()
        .map((service) => service.localized(languageCode))
        .toList(growable: false);

    return _HomePanel(
      icon: Icons.shield_outlined,
      title: 'Settle-in essentials',
      subtitle: 'Trusted practical information from official sources',
      trailing: TextButton(
        onPressed: _openServices,
        child: Text('All services'),
      ),
      child: services.isEmpty
          ? _HomeEmptyState(
              icon: Icons.account_balance_outlined,
              title: 'Civic information is being prepared',
              message: 'Open Local Services to browse practical help.',
              buttonLabel: 'Open Services',
              onTap: _openServices,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 520 ? 2 : 1;
                const gap = 9.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: services.map((service) {
                    final emergency = service.isEmergency;
                    final colour = emergency ? Colors.redAccent : _homeAccent;
                    return SizedBox(
                      width: width,
                      child: Material(
                        color: emergency
                            ? Colors.redAccent.withValues(alpha: 0.1)
                            : _homeCardLight,
                        borderRadius: BorderRadius.circular(19),
                        child: InkWell(
                          onTap: () => _openOfficialLink(service.officialUrl),
                          borderRadius: BorderRadius.circular(19),
                          child: Padding(
                            padding: EdgeInsets.all(13),
                            child: Row(
                              children: [
                                Container(
                                  width: 39,
                                  height: 39,
                                  decoration: BoxDecoration(
                                    color: colour.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    _serviceIcon(service.category),
                                    color: colour,
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        service.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _homeText,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        service.actionLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _homeMuted,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  color: colour,
                                  size: 17,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }

  IconData _serviceIcon(LocalServiceCategory category) {
    return switch (category) {
      LocalServiceCategory.waste => Icons.delete_outline_rounded,
      LocalServiceCategory.transport => Icons.directions_bus_rounded,
      LocalServiceCategory.emergency => Icons.emergency_rounded,
      LocalServiceCategory.council => Icons.campaign_outlined,
      LocalServiceCategory.libraries => Icons.local_library_rounded,
      LocalServiceCategory.parks => Icons.park_outlined,
      LocalServiceCategory.parking => Icons.local_parking_rounded,
      LocalServiceCategory.amenities => Icons.wc_rounded,
      LocalServiceCategory.pets => Icons.pets_rounded,
    };
  }

  Widget _buildSuggestedRoute({required bool desktop}) {
    final strings = AppLocalizations.of(context);
    return _HomePanel(
      icon: Icons.auto_awesome_rounded,
      title: strings.text('suggestedRoute'),
      subtitle: strings.text('suggestedRouteBody'),
      trailing: routes.length < 2
          ? null
          : IconButton(
              tooltip: AppLocalizations.of(
                context,
              ).literal('Show another route'),
              onPressed: _showAnotherRoute,
              icon: Icon(Icons.shuffle_rounded, color: _homeMuted),
            ),
      child: featuredRoute == null
          ? _HomeEmptyState(
              icon: Icons.route_rounded,
              title: 'No route loaded',
              message: 'Check routes.json and pubspec.yaml.',
              buttonLabel: 'Open Map',
              onTap: _openExplore,
            )
          : _buildRouteCard(featuredRoute!, desktop),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route, bool desktop) {
    final saved = savedRoutes.contains(_routeKey(route));
    final content = _localizedExploreContent(route);

    final image = _text(route['image']);

    final title = _text(content['title'], 'Local Route');

    final duration = _text(content['duration'], '--');

    final distance = _text(content['distance'], '--');

    final difficulty = _text(content['difficulty'], 'Easy');

    final xp = _text(route['xp'], '0');

    final description = _text(
      content['description'],
      'A local walk with plenty to discover along the way.',
    );

    return Container(
      height: desktop ? 335 : 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _homeAccent.withValues(alpha: 0.25)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image.isNotEmpty)
            Image.asset(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return _HomeRouteFallback();
              },
            )
          else
            _HomeRouteFallback(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.94),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: 13,
            right: 13,
            child: _HomeRoundButton(
              icon: saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              tooltip: AppLocalizations.of(
                context,
              ).literal(saved ? 'Unsave route' : 'Save route'),
              small: true,
              onTap: () {
                _toggleSavedRoute(route);
              },
            ),
          ),
          Positioned(
            left: 15,
            right: 15,
            bottom: 15,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HomeMiniLabel(
                  icon: Icons.auto_awesome,
                  label: 'SUGGESTED FOR YOU',
                ),
                SizedBox(height: 7),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: desktop ? 27 : 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _HomeMeta(icon: Icons.schedule_rounded, label: duration),
                    _HomeMeta(icon: Icons.navigation_outlined, label: distance),
                    _HomeMeta(icon: Icons.bolt_rounded, label: '+$xp XP'),
                    _HomeDifficultyBadge(label: difficulty),
                  ],
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HomePillButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Start Route',
                      filled: true,
                      onTap: () {
                        _startRoute(route);
                      },
                    ),
                    _HomePillButton(
                      icon: saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: saved ? 'Saved' : 'Save',
                      onTap: () {
                        _toggleSavedRoute(route);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressPanel() {
    final badgeCount = widget.passport.badges.length;
    final earnedBadges = widget.passport.earnedBadgeCount;
    final remaining = max(0, badgeCount - earnedBadges);

    return _HomePanel(
      icon: Icons.insights_rounded,
      title: 'Your Progress',
      subtitle: 'XP, scans and passport badges',
      trailing: widget.onOpenPassport == null
          ? null
          : TextButton.icon(
              onPressed: _openPassport,
              icon: Icon(Icons.auto_stories_outlined, size: 16),
              label: Text('Passport'),
            ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 15),
            decoration: BoxDecoration(
              color: _homeCardLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HomeMetric(
                    icon: Icons.bolt_rounded,
                    value: '+${widget.passport.todayXp}',
                    label: 'XP today',
                    colour: _homeGreen,
                  ),
                ),
                Expanded(
                  child: _HomeMetric(
                    icon: Icons.qr_code_2_rounded,
                    value: '${widget.passport.totalScans}',
                    label: 'scans',
                    colour: _homeAccent,
                  ),
                ),
                Expanded(
                  child: _HomeMetric(
                    icon: Icons.local_fire_department_outlined,
                    value: '$activityStreak',
                    label: 'day streak',
                    colour: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Passport progress',
                  style: TextStyle(
                    color: _homeText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$earnedBadges/$badgeCount',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: passportProgress,
              minHeight: 9,
              backgroundColor: AppThemeColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                color: Colors.orangeAccent,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  badgeCount == 0
                      ? 'Your badge collection is getting ready.'
                      : remaining == 0
                      ? 'Every passport badge has been earned!'
                      : '$remaining badge${remaining == 1 ? '' : 's'} still waiting.',
                  style: TextStyle(
                    color: _homeMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(onPressed: _openPassport, child: Text('View')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyPanel() {
    final sortedPlaces = List<Map<String, dynamic>>.of(locations);
    if (_currentPosition != null) {
      sortedPlaces.sort((first, second) {
        final firstDistance = _distanceTo(first) ?? double.infinity;
        final secondDistance = _distanceTo(second) ?? double.infinity;
        return firstDistance.compareTo(secondDistance);
      });
    }
    final nearby = sortedPlaces.take(6).toList();

    return _HomePanel(
      icon: Icons.near_me_outlined,
      title: 'Around You',
      subtitle: _currentPosition == null
          ? 'Popular places across Canada Bay'
          : 'Sorted using your current location',
      trailing: TextButton.icon(
        onPressed: _locating ? null : _useCurrentLocation,
        icon: _locating
            ? SizedBox.square(
                dimension: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _currentPosition == null
                    ? Icons.my_location_rounded
                    : Icons.refresh_rounded,
                size: 16,
              ),
        label: Text(_currentPosition == null ? 'Near me' : 'Refresh'),
      ),
      child: nearby.isEmpty
          ? _HomeEmptyState(
              icon: Icons.place_outlined,
              title: 'No checkpoints loaded',
              message: 'Check locations.json and pubspec.yaml.',
              buttonLabel: 'Retry',
              onTap: _loadHomeData,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 520) {
                  return SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: nearby.length,
                      separatorBuilder: (_, _) {
                        return SizedBox(width: 9);
                      },
                      itemBuilder: (context, index) {
                        final location = nearby[index];
                        final content = _localizedExploreContent(location);

                        return SizedBox(
                          width: 195,
                          child: _HomePlaceTile(
                            location: content,
                            icon: _iconForType(location['type']),
                            colour: _colourForType(location['type']),
                            typeLabel: _typeAndDistanceLabel(location),
                            collected: _hasScannedLocation(location),
                            onTap: () {
                              _showPlaceSheet(location);
                            },
                          ),
                        );
                      },
                    ),
                  );
                }

                final columns = constraints.maxWidth >= 700 ? 2 : 2;

                final tileWidth =
                    (constraints.maxWidth - ((columns - 1) * 10)) / columns;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: nearby.map((location) {
                    final content = _localizedExploreContent(location);
                    return SizedBox(
                      width: tileWidth,
                      child: _HomePlaceTile(
                        location: content,
                        icon: _iconForType(location['type']),
                        colour: _colourForType(location['type']),
                        typeLabel: _typeAndDistanceLabel(location),
                        collected: _hasScannedLocation(location),
                        onTap: () {
                          _showPlaceSheet(location);
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }

  Widget _buildCommunityPanel() {
    final languageCode = Localizations.localeOf(context).languageCode;
    final item = featuredCommunity?.localized(languageCode);
    final copy = CommunityServicesLocalizations.of(context);

    return _HomePanel(
      icon: Icons.groups_rounded,
      title: 'Featured community activity',
      subtitle: 'A welcoming way to meet your neighbourhood',
      child: item == null
          ? _HomeEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Community activities are being prepared',
              message: 'Open Community to browse the complete local guide.',
              buttonLabel: 'Open Community',
              onTap: _openCommunity,
            )
          : Container(
              width: double.infinity,
              padding: EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AppThemeColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _homeAccent.withValues(alpha: 0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeMiniLabel(
                    icon: Icons.event_available_rounded,
                    label: copy
                        .communityCategory(item.category.name)
                        .toUpperCase(),
                  ),
                  SizedBox(height: 10),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: _homeText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    item.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _homeMuted,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: 12),
                  _HomeDetailLine(
                    icon: Icons.schedule_rounded,
                    text: item.schedule,
                  ),
                  SizedBox(height: 7),
                  _HomeDetailLine(
                    icon: Icons.place_outlined,
                    text: item.location,
                  ),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HomePillButton(
                        icon: Icons.groups_rounded,
                        label: 'Explore Community',
                        filled: true,
                        onTap: _openCommunity,
                      ),
                      _HomePillButton(
                        icon: Icons.open_in_new_rounded,
                        label: 'Official details',
                        onTap: () => _openOfficialLink(item.officialUrl),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEnvironmentalPanel() {
    final canonicalStory = environmentalStories.isEmpty
        ? null
        : environmentalStories.first;
    final story = canonicalStory?.localized(Localizations.localeOf(context));

    return _HomePanel(
      icon: Icons.eco_rounded,
      title: 'Environmental discovery',
      subtitle: 'Learn about the living places around you',
      child: story == null
          ? _HomeEmptyState(
              icon: Icons.nature_outlined,
              title: 'Environmental stories are being prepared',
              message: 'Try again when local content is available.',
              buttonLabel: 'Try again',
              onTap: _loadHomeData,
            )
          : Container(
              width: double.infinity,
              padding: EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AppThemeColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeMiniLabel(
                    icon: Icons.water_rounded,
                    label: story.category.toUpperCase(),
                  ),
                  SizedBox(height: 10),
                  Text(
                    story.name,
                    style: TextStyle(
                      color: _homeText,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    story.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _homeMuted,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HomePillButton(
                        icon: Icons.map_rounded,
                        label: 'Find on map',
                        filled: true,
                        onTap: () => _openPlace(<String, dynamic>{
                          'id': story.id,
                          'name': story.name,
                          'lat': story.latitude,
                          'lng': story.longitude,
                        }),
                      ),
                      _HomePillButton(
                        icon: Icons.open_in_new_rounded,
                        label: 'Official source',
                        onTap: () => _openOfficialLink(story.officialUrl),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildActivityPanel() {
    final recent = recentActivities;

    return _HomePanel(
      icon: Icons.history_rounded,
      title: 'Recent Activity',
      subtitle: 'Your latest discoveries',
      child: recent.isEmpty
          ? Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _homeCardLight,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: _homeGreen),
                  SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Scan a checkpoint or save a route to begin your activity feed.',
                      style: TextStyle(
                        color: _homeMuted,
                        fontSize: 11,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: recent.take(5).map((activity) {
                return Container(
                  margin: EdgeInsets.only(bottom: 9),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _homeCardLight,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: activity.colour.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(activity.icon, color: activity.colour),
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: TextStyle(
                                color: _homeText,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              activity.subtitle,
                              style: TextStyle(
                                color: _homeMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  void _showPassportSheet() {
    final badges = widget.passport.badges;
    final earned = badges.where((badge) => badge.earned).toList();

    _showBottomSheet(
      title: 'Digital Passport',
      subtitle: 'Scan real places to earn XP and complete badge collections.',
      icon: Icons.workspace_premium_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.passport.earnedBadgeCount}/${badges.length} badges earned',
            style: TextStyle(
              color: _homeText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: passportProgress,
              minHeight: 9,
              backgroundColor: AppThemeColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
            ),
          ),
          SizedBox(height: 18),
          if (earned.isEmpty)
            Text(
              'No badges yet. Scan a passport QR code to start your first collection.',
              style: TextStyle(color: _homeMuted, height: 1.4),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: earned
                  .map(
                    (badge) => Chip(
                      avatar: Icon(
                        Icons.verified_rounded,
                        color: _homeGreen,
                        size: 17,
                      ),
                      label: Text(
                        badge.localizedName(
                          Localizations.localeOf(context).languageCode,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          SizedBox(height: 18),
          _HomePillButton(
            icon: Icons.auto_stories_rounded,
            label: 'Open full passport',
            filled: true,
            onTap: widget.onOpenPassport == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    _openPassport();
                  },
          ),
        ],
      ),
    );
  }

  void _showPlaceSheet(Map<String, dynamic> location) {
    final collected = _hasScannedLocation(location);
    final content = _localizedExploreContent(location);

    _showBottomSheet(
      title: _text(content['name'], 'Checkpoint'),
      subtitle: _typeLabel(location['type']),
      icon: _iconForType(location['type']),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_text(content['description']).isNotEmpty) ...[
            Text(
              _text(content['description']),
              style: TextStyle(
                color: _homeText,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 15),
          ],
          if (_text(content['address']).isNotEmpty) ...[
            _HomeDetailLine(
              icon: Icons.place_outlined,
              text: _text(content['address']),
            ),
            SizedBox(height: 15),
          ],
          _HomeMiniLabel(
            icon: Icons.my_location_rounded,
            label: 'MAP COORDINATES',
          ),
          SizedBox(height: 7),
          Text(
            '${_text(location['lat'], '--')}, '
            '${_text(location['lng'], '--')}',
            style: TextStyle(color: _homeMuted),
          ),
          SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HomePillButton(
                icon: Icons.map_rounded,
                label: 'Explore map',
                filled: true,
                onTap: () {
                  Navigator.of(context).pop();
                  _openPlace(location);
                },
              ),
              _HomePillButton(
                icon: collected
                    ? Icons.auto_stories_rounded
                    : Icons.qr_code_scanner_rounded,
                label: collected ? 'View in Passport' : 'Scan this place',
                onTap: () {
                  Navigator.of(context).pop();
                  if (collected) {
                    _openPassport();
                  } else {
                    _openScanner();
                  }
                },
              ),
              if (_text(location['officialUrl']).isNotEmpty)
                _HomePillButton(
                  icon: Icons.open_in_new_rounded,
                  label: 'Official details',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openOfficialLink(_text(location['officialUrl']));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBottomSheet({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
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
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: 620,
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.84,
              ),
              margin: EdgeInsets.all(14),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _homeDark,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _homeAccent.withValues(alpha: 0.3)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 43,
                          height: 43,
                          decoration: BoxDecoration(
                            color: _homeGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: _homeGreen),
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: _homeText,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: _homeMuted,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                          },
                          icon: Icon(Icons.close_rounded, color: _homeMuted),
                        ),
                      ],
                    ),
                    SizedBox(height: 18),
                    child,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _iconForType(dynamic type) {
    final value = type?.toString().toLowerCase() ?? '';

    if (value.contains('food') ||
        value.contains('cafe') ||
        value.contains('restaurant')) {
      return Icons.restaurant_rounded;
    }

    if (value.contains('park')) {
      return Icons.park_rounded;
    }

    if (value.contains('gym') || value.contains('fitness')) {
      return Icons.fitness_center_rounded;
    }

    if (value.contains('library')) {
      return Icons.local_library_rounded;
    }

    if (value.contains('toilet')) {
      return Icons.wc_rounded;
    }

    if (value.contains('business') || value.contains('shop')) {
      return Icons.storefront_rounded;
    }

    if (value.contains('community') || value.contains('club')) {
      return Icons.groups_rounded;
    }

    if (value.contains('attraction') ||
        value.contains('landmark') ||
        value.contains('heritage')) {
      return Icons.camera_alt_rounded;
    }

    if (value.contains('biodiversity') ||
        value.contains('bird') ||
        value.contains('wildlife')) {
      return Icons.eco_rounded;
    }

    return Icons.place_rounded;
  }

  Color _colourForType(dynamic type) {
    final value = type?.toString().toLowerCase() ?? '';

    if (value.contains('food') ||
        value.contains('cafe') ||
        value.contains('restaurant')) {
      return Colors.orangeAccent;
    }

    if (value.contains('park')) {
      return _homeGreen;
    }

    if (value.contains('gym') || value.contains('fitness')) {
      return Colors.redAccent;
    }

    if (value.contains('library')) {
      return _homeAccent;
    }

    if (value.contains('toilet')) {
      return _homeMuted;
    }

    if (value.contains('business') || value.contains('shop')) {
      return Colors.orangeAccent;
    }

    if (value.contains('community') || value.contains('club')) {
      return _homeAccent;
    }

    if (value.contains('attraction') ||
        value.contains('landmark') ||
        value.contains('heritage')) {
      return Color(0xFFB892FF);
    }

    if (value.contains('biodiversity') ||
        value.contains('bird') ||
        value.contains('wildlife')) {
      return Color(0xFF79C96B);
    }

    return _homeBlue;
  }

  String _typeLabel(dynamic type) {
    final value = type?.toString().toLowerCase() ?? '';
    final copy = ExploreLocalizations.of(context);

    if (value.contains('food') ||
        value.contains('cafe') ||
        value.contains('restaurant')) {
      return copy.kindLabel('food');
    }

    if (value.contains('park')) {
      return copy.kindLabel('park');
    }

    if (value.contains('gym') || value.contains('fitness')) {
      return copy.kindLabel('gym');
    }

    if (value.contains('library')) {
      return copy.kindLabel('library');
    }

    if (value.contains('toilet')) {
      return copy.kindLabel('toilet');
    }

    if (value.contains('business') || value.contains('shop')) {
      return AppLocalizations.of(context).literal('Local business');
    }

    if (value.contains('community') || value.contains('club')) {
      return copy.kindLabel('community');
    }

    if (value.contains('attraction') ||
        value.contains('landmark') ||
        value.contains('heritage')) {
      return copy.kindLabel('attraction');
    }

    if (value.contains('biodiversity') ||
        value.contains('bird') ||
        value.contains('wildlife')) {
      return copy.kindLabel('biodiversity');
    }

    return copy.kindLabel('checkpoint');
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 82,
            height: 82,
            padding: EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(27),
              boxShadow: [
                BoxShadow(
                  color: _homeGreen.withValues(alpha: 0.2),
                  blurRadius: 30,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Image.asset(
                _homeLogoAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return Icon(
                    Icons.sailing_rounded,
                    color: _homeBlue,
                    size: 42,
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Finding local adventures…',
            style: TextStyle(
              color: _homeText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 14),
          SizedBox(
            width: 118,
            child: LinearProgressIndicator(
              minHeight: 4,
              borderRadius: BorderRadius.all(Radius.circular(99)),
              color: _homeGreen,
              backgroundColor: _homeCardLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _HomePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _homeMuted.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _homeMuted, size: 20),
              ),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _homeText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _homeMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          SizedBox(height: 17),
          child,
        ],
      ),
    );
  }
}

class _HomeStatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color colour;

  const _HomeStatusPill({
    required this.icon,
    required this.label,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colour.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colour, size: 16),
          SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: _homeText,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color colour;
  final VoidCallback onTap;

  const _HomeActionTile({
    required this.icon,
    required this.label,
    required this.colour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _homeCardLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 94,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colour, size: 29),
              SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _homeText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color colour;

  const _HomeMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: colour, size: 20),
        SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _homeText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _homeMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HomePlaceTile extends StatelessWidget {
  final Map<String, dynamic> location;
  final IconData icon;
  final Color colour;
  final String typeLabel;
  final bool collected;
  final VoidCallback onTap;

  const _HomePlaceTile({
    required this.location,
    required this.icon,
    required this.colour,
    required this.typeLabel,
    required this.collected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _homeCardLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 116,
          padding: EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: collected
                  ? _homeGreen.withValues(alpha: 0.5)
                  : _homeAccent.withValues(alpha: 0.17),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (collected ? _homeGreen : colour).withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  collected ? Icons.verified_rounded : icon,
                  color: collected ? _homeGreen : colour,
                  size: 19,
                ),
              ),
              Spacer(),
              Text(
                location['name']?.toString() ?? 'Checkpoint',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _homeText, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 3),
              Text(
                collected ? 'Stamp collected' : typeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: collected ? _homeGreen : _homeMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _HomePillButton({
    required this.icon,
    required this.label,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Material(
      color: filled
          ? disabled
                ? Colors.grey.withValues(alpha: 0.3)
                : _homeGreen
          : _homeCard,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: filled
                ? null
                : Border.all(color: _homeAccent.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: filled ? Colors.white : _homeMuted, size: 16),
              SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : _homeText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool small;

  const _HomeRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 40.0 : 48.0;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: _homeCard.withValues(alpha: 0.95),
        shape: CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: small ? _homeGreen : _homeMuted,
              size: small ? 20 : 23,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeMiniLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HomeMiniLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _homeGreen, size: 14),
        SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _homeMuted,
              fontSize: 10,
              letterSpacing: 1.9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeDetailLine extends StatelessWidget {
  const _HomeDetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _homeGreen, size: 15),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _homeMuted,
              fontSize: 10.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HomeMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 13),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HomeDifficultyBadge extends StatelessWidget {
  final String label;

  const _HomeDifficultyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final value = label.toLowerCase();

    final colour = value.contains('hard')
        ? Colors.redAccent
        : value.contains('moderate')
        ? Colors.orangeAccent
        : _homeGreen;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colour,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HomeRouteFallback extends StatelessWidget {
  const _HomeRouteFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _homeBlue,
      child: Center(
        child: Icon(Icons.route_rounded, color: Colors.white, size: 54),
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onTap;

  const _HomeEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: _homeCardLight,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Column(
        children: [
          Icon(icon, color: _homeMuted, size: 34),
          SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: _homeText, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _homeMuted, fontSize: 11, height: 1.4),
          ),
          SizedBox(height: 12),
          _HomePillButton(
            icon: Icons.arrow_forward_rounded,
            label: buttonLabel,
            filled: true,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _HomeActivity {
  final IconData icon;
  final Color colour;
  final String title;
  final String subtitle;

  _HomeActivity({
    required this.icon,
    required this.colour,
    required this.title,
    required this.subtitle,
  });
}
