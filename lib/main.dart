import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_localizations.dart';
import 'models/account_profile.dart';
import 'models/app_preferences.dart';
import 'models/passport.dart';
import 'models/settlement_profile.dart';
import 'screens/community_screen.dart' as community;
import 'screens/home_screen.dart' as home;
import 'screens/explore_screen.dart' as explore;
import 'screens/local_services_screen.dart' as services;
import 'screens/newcomer_journey_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/passport_screen.dart' as passport_screen;
import 'screens/profile_screen.dart' as profile;
import 'screens/scan_screen.dart' as scan;
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart' as nav;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  SupabaseClient? supabase;
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    supabase = Supabase.instance.client;
  } else {
    debugPrint(
      'Supabase is not configured. Start the app with SUPABASE_URL and '
      'SUPABASE_PUBLISHABLE_KEY dart-defines to enable accounts.',
    );
  }

  final account = AccountProfileController(supabase: supabase);
  final preferences = AppPreferencesController();
  final settlement = SettlementProfileController();
  await Future.wait([account.load(), preferences.load(), settlement.load()]);
  final passport = PassportController(ownerId: account.passportOwnerId);
  await passport.load();
  runApp(
    ExploreCanadaBayApp(
      passport: passport,
      account: account,
      preferences: preferences,
      settlement: settlement,
    ),
  );
}

class ExploreCanadaBayApp extends StatelessWidget {
  final PassportController passport;
  final AccountProfileController account;
  final AppPreferencesController preferences;
  final SettlementProfileController settlement;

  const ExploreCanadaBayApp({
    super.key,
    required this.passport,
    required this.account,
    required this.preferences,
    required this.settlement,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([account, preferences]),
      builder: (context, _) {
        AppThemeColors.mode = account.themeMode;
        unawaited(passport.switchOwner(account.passportOwnerId));

        return MaterialApp(
          title: 'Explore Canada Bay',
          debugShowCheckedModeBanner: false,
          locale: preferences.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: account.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: preferences.onboardingComplete
              ? MainShell(
                  passport: passport,
                  account: account,
                  preferences: preferences,
                  settlement: settlement,
                )
              : OnboardingScreen(preferences: preferences, account: account),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00B87A),
        brightness: brightness,
      ),
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF071E35)
          : Colors.white,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final PassportController passport;
  final AccountProfileController account;
  final AppPreferencesController preferences;
  final SettlementProfileController settlement;

  const MainShell({
    super.key,
    required this.passport,
    required this.account,
    required this.preferences,
    required this.settlement,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _homeIndex = 0;
  static const _exploreIndex = 1;
  static const _communityIndex = 2;
  static const _servicesIndex = 3;
  static const _passportIndex = 4;
  static const _scanIndex = 5;
  static const _profileIndex = 6;
  static const _journeyIndex = 7;

  late int _selectedIndex;
  String? _requestedRouteId;
  int _routeRequestVersion = 0;
  String? _requestedExploreFilter;
  String? _requestedPlaceName;
  int _exploreRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.settlement.tutorialSeen
        ? _homeIndex
        : _journeyIndex;
  }

  void _goToPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openRoute(Map<String, dynamic> route) {
    final routeId = route['id']?.toString() ?? route['title']?.toString();
    if (routeId == null || routeId.trim().isEmpty) {
      _goToPage(_exploreIndex);
      return;
    }

    setState(() {
      _requestedRouteId = routeId.trim();
      _routeRequestVersion++;
      _selectedIndex = _exploreIndex;
    });
  }

  void _openExplore({String filter = 'All', String? placeName}) {
    setState(() {
      _requestedExploreFilter = filter;
      _requestedPlaceName = placeName;
      _exploreRequestVersion++;
      _selectedIndex = _exploreIndex;
    });
  }

  List<Widget> get _pages => [
    home.HomeScreen(
      passport: widget.passport,
      explorerName: widget.account.profileVisible
          ? widget.account.name
          : AppLocalizations(widget.preferences.locale).literal('Explorer'),
      residentType: widget.preferences.residentType,
      interests: widget.preferences.interests,
      settlement: widget.settlement,
      onOpenScan: () => _goToPage(_scanIndex),
      onOpenRoutes: () => _openExplore(filter: 'Routes'),
      onOpenExplore: () => _openExplore(),
      onOpenPlace: (place) => _openExplore(
        placeName:
            place['id']?.toString() ??
            place['name']?.toString() ??
            place['title']?.toString(),
      ),
      onStartRoute: _openRoute,
      onOpenPassport: () => _goToPage(_passportIndex),
      onOpenProfile: () => _goToPage(_profileIndex),
      onOpenCommunity: () => _goToPage(_communityIndex),
      onOpenServices: () => _goToPage(_servicesIndex),
      onOpenJourney: () => _goToPage(_journeyIndex),
    ),
    explore.ExploreScreen(
      passport: widget.passport,
      requestedRouteId: _requestedRouteId,
      routeRequestVersion: _routeRequestVersion,
      requestedFilter: _requestedExploreFilter,
      requestedPlaceName: _requestedPlaceName,
      exploreRequestVersion: _exploreRequestVersion,
    ),
    community.CommunityScreen(onOpenJourney: () => _goToPage(_journeyIndex)),
    services.LocalServicesScreen(onOpenJourney: () => _goToPage(_journeyIndex)),
    passport_screen.PassportScreen(
      passport: widget.passport,
      explorerName: widget.account.profileVisible
          ? widget.account.name
          : AppLocalizations(widget.preferences.locale).literal('Explorer'),
      isSignedIn: widget.account.isSignedIn,
      showFeaturedAchievements:
          widget.account.profileVisible && widget.account.showAchievements,
      settlement: widget.settlement,
      onOpenScanner: () => _goToPage(_scanIndex),
      onOpenProfile: () => _goToPage(_profileIndex),
      onOpenJourney: () => _goToPage(_journeyIndex),
    ),
    scan.ScanScreen(
      passport: widget.passport,
      isActive: _selectedIndex == _scanIndex,
      onOpenPassport: () => _goToPage(_passportIndex),
    ),
    profile.ProfileScreen(
      controller: widget.account,
      preferences: widget.preferences,
    ),
    NewcomerJourneyScreen(
      passport: widget.passport,
      settlement: widget.settlement,
      onFinishTutorial: () {
        unawaited(widget.settlement.markTutorialSeen());
        _goToPage(_homeIndex);
      },
      onOpenServices: () => _goToPage(_servicesIndex),
      onOpenExplore: () => _openExplore(filter: 'Routes'),
      onOpenCommunity: () => _goToPage(_communityIndex),
      onOpenScanner: () => _goToPage(_scanIndex),
      onOpenHome: () => _goToPage(_homeIndex),
      onOpenPassport: () => _goToPage(_passportIndex),
      onOpenProfile: () => _goToPage(_profileIndex),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: nav.AppBottomNav(
        selectedIndex: _selectedIndex <= _passportIndex ? _selectedIndex : -1,
        onTap: _goToPage,
      ),
    );
  }
}
