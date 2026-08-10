import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../l10n/journey_activity_localizations.dart';
import '../l10n/journey_localizations.dart';
import '../models/newcomer_journey.dart';
import '../models/passport.dart';
import '../models/settlement_profile.dart';
import '../services/bin_notification_service.dart';
import '../services/external_link_service.dart';
import '../services/newcomer_journey_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/localized_text.dart';

enum _JourneyNeed { settle, findWay, meetPeople, careTogether }

extension on _JourneyNeed {
  String get labelKey => switch (this) {
    _JourneyNeed.settle => 'needSettle',
    _JourneyNeed.findWay => 'needFindWay',
    _JourneyNeed.meetPeople => 'needMeetPeople',
    _JourneyNeed.careTogether => 'needCareTogether',
  };

  String get reasonKey => switch (this) {
    _JourneyNeed.settle => 'needSettleReason',
    _JourneyNeed.findWay => 'needFindWayReason',
    _JourneyNeed.meetPeople => 'needMeetPeopleReason',
    _JourneyNeed.careTogether => 'needCareTogetherReason',
  };

  IconData get icon => switch (this) {
    _JourneyNeed.settle => Icons.home_rounded,
    _JourneyNeed.findWay => Icons.near_me_rounded,
    _JourneyNeed.meetPeople => Icons.waving_hand_rounded,
    _JourneyNeed.careTogether => Icons.eco_rounded,
  };

  List<String> get taskIds => switch (this) {
    _JourneyNeed.settle => const [
      'know-triple-zero',
      'use-an-interpreter',
      'find-bin-day',
      'check-medicare',
      'know-rental-rights',
      'home-pool-safety',
    ],
    _JourneyNeed.findWay => const [
      'plan-first-trip',
      'complete-local-route',
      'swim-between-flags',
    ],
    _JourneyNeed.meetPeople => const [
      'discover-library',
      'find-english-support',
      'join-community-activity',
    ],
    _JourneyNeed.careTogether => const [
      'help-local-environment',
      'complete-local-route',
      'swim-between-flags',
    ],
  };
}

class _JourneyChapterDefinition {
  const _JourneyChapterDefinition({
    required this.titleKey,
    required this.bodyKey,
    required this.icon,
    required this.colour,
    required this.taskIds,
  });

  final String titleKey;
  final String bodyKey;
  final IconData icon;
  final Color colour;
  final List<String> taskIds;
}

const _journeyChapters = <_JourneyChapterDefinition>[
  _JourneyChapterDefinition(
    titleKey: 'chapterSettleTitle',
    bodyKey: 'chapterSettleBody',
    icon: Icons.shield_rounded,
    colour: Color(0xFF3979C7),
    taskIds: [
      'know-triple-zero',
      'use-an-interpreter',
      'find-bin-day',
      'check-medicare',
      'know-rental-rights',
    ],
  ),
  _JourneyChapterDefinition(
    titleKey: 'chapterRhythmTitle',
    bodyKey: 'chapterRhythmBody',
    icon: Icons.route_rounded,
    colour: Color(0xFF008F73),
    taskIds: ['plan-first-trip', 'complete-local-route'],
  ),
  _JourneyChapterDefinition(
    titleKey: 'chapterPeopleTitle',
    bodyKey: 'chapterPeopleBody',
    icon: Icons.groups_rounded,
    colour: Color(0xFF8E68C7),
    taskIds: [
      'discover-library',
      'find-english-support',
      'join-community-activity',
    ],
  ),
  _JourneyChapterDefinition(
    titleKey: 'chapterCareTitle',
    bodyKey: 'chapterCareBody',
    icon: Icons.volunteer_activism_rounded,
    colour: Color(0xFFD56B42),
    taskIds: [
      'swim-between-flags',
      'home-pool-safety',
      'help-local-environment',
    ],
  ),
];

class NewcomerJourneyScreen extends StatefulWidget {
  const NewcomerJourneyScreen({
    super.key,
    required this.passport,
    required this.settlement,
    this.repository = const NewcomerJourneyRepository(),
    this.onOpenServices,
    this.onOpenExplore,
    this.onOpenCommunity,
    this.onOpenScanner,
    this.onOpenHome,
    this.onOpenPassport,
    this.onOpenProfile,
    this.onFinishTutorial,
  });

  final PassportController passport;
  final SettlementProfileController settlement;
  final NewcomerJourneyRepository repository;
  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenExplore;
  final VoidCallback? onOpenCommunity;
  final VoidCallback? onOpenScanner;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenPassport;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onFinishTutorial;

  @override
  State<NewcomerJourneyScreen> createState() => _NewcomerJourneyScreenState();
}

class _NewcomerJourneyScreenState extends State<NewcomerJourneyScreen> {
  late Future<NewcomerJourneyCatalog> _catalog;
  late final PageController _tutorialController;
  String? _savingTaskId;
  _JourneyNeed _selectedNeed = _JourneyNeed.settle;
  int _tutorialPage = 0;
  bool _showOverview = false;

  @override
  void initState() {
    super.initState();
    _catalog = widget.repository.loadCatalog();
    _tutorialController = PageController();
  }

  @override
  void dispose() {
    _tutorialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: FutureBuilder<NewcomerJourneyCatalog>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _JourneyError(
              onRetry: () {
                setState(() => _catalog = widget.repository.loadCatalog());
              },
            );
          }
          return ListenableBuilder(
            listenable: Listenable.merge([widget.passport, widget.settlement]),
            builder: (context, _) => _buildJourney(snapshot.requireData),
          );
        },
      ),
    );
  }

  Widget _buildJourney(NewcomerJourneyCatalog catalog) {
    if (_showOverview) return _buildJourneyOverview(catalog);
    return _buildPagedJourney(catalog);
  }

  Widget _buildPagedJourney(NewcomerJourneyCatalog catalog) {
    final copy = JourneyLocalizations.of(context);
    final tasks = catalog.tasks;
    final totalPages = tasks.length + 2;
    final completed = tasks
        .where(
          (task) => _isTaskComplete(widget.passport, task, widget.settlement),
        )
        .length;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _JourneyTutorialHeader(
            title: copy.ui('tutorialTitle'),
            pageLabel: copy.message('tutorialPage', {
              'current': _tutorialPage + 1,
              'total': totalPages,
            }),
            progress: progress,
            onOverview: () => setState(() => _showOverview = true),
            overviewTooltip: copy.ui('tutorialOverview'),
          ),
          Expanded(
            child: PageView.builder(
              key: const ValueKey('journey-tutorial-pages'),
              controller: _tutorialController,
              itemCount: totalPages,
              onPageChanged: (page) => setState(() => _tutorialPage = page),
              itemBuilder: (context, page) {
                if (page == 0) {
                  return _JourneyTutorialIntro(
                    completed: completed,
                    total: tasks.length,
                  );
                }
                if (page == totalPages - 1) {
                  return _JourneyTutorialFinish(
                    completed: completed,
                    total: tasks.length,
                    onOpenHome: widget.onOpenHome,
                    onOpenPassport: widget.onOpenPassport,
                    onOpenProfile: widget.onOpenProfile,
                  );
                }

                final taskIndex = page - 1;
                final task = tasks[taskIndex];
                final taskCompleted = _isTaskComplete(
                  widget.passport,
                  task,
                  widget.settlement,
                );
                final placement = _tutorialPlacement(task);
                final usesSetupFlow =
                    task.id == 'find-bin-day' ||
                    task.id == 'discover-library' ||
                    task.id == 'plan-first-trip';
                final inlineSetup = switch (task.id) {
                  'find-bin-day' => _TutorialBinSetup(
                    settlement: widget.settlement,
                    saving: _savingTaskId == task.id,
                    onSave: _saveBinNight,
                  ),
                  'discover-library' => _TutorialLibrarySetup(
                    initialValue: widget.settlement.libraryCardLabel,
                    saving: _savingTaskId == task.id,
                    onSave: (value) => _saveLibraryCard(value, points: task.xp),
                  ),
                  'plan-first-trip' => _TutorialTransportSetup(
                    settlement: widget.settlement,
                    saving: _savingTaskId == task.id,
                    onSave: _saveTransport,
                  ),
                  _ => null,
                };
                return _JourneyTutorialTaskPage(
                  key: ValueKey('journey-tutorial-task:${task.id}'),
                  day: _journeyDay(taskIndex),
                  task: task,
                  completed: taskCompleted,
                  saving: _savingTaskId == task.id,
                  featureKey: placement.featureKey,
                  storageKey: placement.storageKey,
                  icon: placement.icon,
                  colour: placement.colour,
                  onOpen: () => _openTutorialTask(task),
                  inlineSetup: inlineSetup,
                  onScan:
                      task.verification == JourneyVerification.qr &&
                          widget.onOpenScanner != null
                      ? widget.onOpenScanner
                      : null,
                  onComplete:
                      task.canSelfComplete && !taskCompleted && !usesSetupFlow
                      ? () => _completeLearningTask(task)
                      : null,
                );
              },
            ),
          ),
          _JourneyTutorialNavigation(
            currentPage: _tutorialPage,
            totalPages: totalPages,
            onBack: _tutorialPage == 0
                ? null
                : () => _moveTutorialTo(_tutorialPage - 1),
            onNext: () {
              if (_tutorialPage == totalPages - 1) {
                final finish = widget.onFinishTutorial;
                if (finish != null) {
                  finish();
                } else {
                  _moveTutorialTo(0);
                }
                return;
              }
              if (_tutorialPage == 0) {
                final firstIncomplete = tasks.indexWhere(
                  (task) => !_isTaskComplete(
                    widget.passport,
                    task,
                    widget.settlement,
                  ),
                );
                _moveTutorialTo(
                  firstIncomplete < 0 ? totalPages - 1 : firstIncomplete + 1,
                );
                return;
              }
              _moveTutorialTo(_tutorialPage + 1);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _moveTutorialTo(int page) async {
    if (!_tutorialController.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _tutorialController.jumpToPage(page);
      return;
    }
    await _tutorialController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openTutorialTask(NewcomerJourneyTask task) async {
    if (task.id == 'find-bin-day' ||
        task.id == 'discover-library' ||
        task.id == 'plan-first-trip') {
      await _showTask(task);
      return;
    }
    await _openTask(task);
  }

  int _journeyDay(int taskIndex) {
    const milestones = <int>[1, 2, 3, 5, 7, 9, 11, 14, 16, 19, 22, 26, 30];
    if (taskIndex < milestones.length) return milestones[taskIndex];
    return ((taskIndex + 1) * 30 / 13).round().clamp(1, 30).toInt();
  }

  ({String featureKey, String storageKey, IconData icon, Color colour})
  _tutorialPlacement(NewcomerJourneyTask task) {
    if (task.id == 'find-bin-day' ||
        task.id == 'plan-first-trip' ||
        task.id == 'discover-library') {
      return (
        featureKey: 'featureServices',
        storageKey: 'storedEssentials',
        icon: Icons.home_work_rounded,
        colour: const Color(0xFF3979C7),
      );
    }
    if (task.verification == JourneyVerification.route ||
        task.destination == 'explore') {
      return (
        featureKey: 'featureExplore',
        storageKey: 'storedRoutePassport',
        icon: Icons.explore_rounded,
        colour: const Color(0xFF008F73),
      );
    }
    if (task.verification == JourneyVerification.qr) {
      return (
        featureKey: 'featureCommunityScan',
        storageKey: 'storedScanPassport',
        icon: Icons.qr_code_scanner_rounded,
        colour: const Color(0xFF8E68C7),
      );
    }
    if (task.destination == 'services') {
      return (
        featureKey: 'featureServices',
        storageKey: 'storedJourneyPassport',
        icon: Icons.support_agent_rounded,
        colour: const Color(0xFF3979C7),
      );
    }
    return (
      featureKey: 'featureJourney',
      storageKey: 'storedJourneyPassport',
      icon: _kindIcon(task.kind),
      colour: _kindColor(task.kind),
    );
  }

  Widget _buildJourneyOverview(NewcomerJourneyCatalog catalog) {
    final copy = JourneyLocalizations.of(context);
    final completed = catalog.tasks
        .where(
          (task) => _isTaskComplete(widget.passport, task, widget.settlement),
        )
        .length;
    final progress = catalog.tasks.isEmpty
        ? 0.0
        : completed / catalog.tasks.length;
    final focusTask = _focusTask(catalog, _selectedNeed);
    final journeyMoments = widget.passport.scanHistory
        .where((record) => record.rewardId.startsWith('journey:'))
        .toList(growable: false);
    final journeyActivityCopy = JourneyActivityLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).width < 700;

    return CustomScrollView(
      key: const PageStorageKey<String>('settlement-companion-scroll'),
      slivers: [
        SliverAppBar(
          expandedHeight: compact ? 410 : 300,
          pinned: true,
          backgroundColor: const Color(0xFF06304A),
          foregroundColor: Colors.white,
          title: Text(
            copy.ui('journeyTitle'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: copy.ui('tutorialPages'),
              onPressed: () => setState(() => _showOverview = false),
              icon: const Icon(Icons.view_carousel_rounded),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _JourneyHero(
              completed: completed,
              total: catalog.tasks.length,
              progress: progress,
              setupCount: widget.settlement.usefulToolCount,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeading(
                      eyebrow: copy.ui('companionCheckInEyebrow'),
                      title: copy.ui('companionCheckInTitle'),
                      body: copy.ui('companionCheckInBody'),
                    ),
                    const SizedBox(height: 18),
                    _JourneyNeedPicker(
                      selected: _selectedNeed,
                      onSelected: (need) {
                        if (need == _selectedNeed) return;
                        setState(() => _selectedNeed = need);
                      },
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final status = _ConnectionPulse(
                          completed: completed,
                          total: catalog.tasks.length,
                          setupCount: widget.settlement.usefulToolCount,
                          moments: journeyMoments.length,
                          latestMoment: journeyMoments.isEmpty
                              ? null
                              : journeyActivityCopy
                                    .resolve(
                                      journeyMoments.first,
                                      settlement: widget.settlement,
                                    )
                                    .placeName,
                          onOpenWholeJourney: () =>
                              _showJourneyCollection(catalog.tasks),
                        );
                        final focus = AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.035, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: focusTask == null
                              ? _JourneyCompleteCard(
                                  key: const ValueKey('journey-complete'),
                                  onExplore: widget.onFinishTutorial,
                                )
                              : _NextJourneyStep(
                                  key: ValueKey(focusTask.id),
                                  task: focusTask,
                                  completed: _isTaskComplete(
                                    widget.passport,
                                    focusTask,
                                    widget.settlement,
                                  ),
                                  reason: copy.ui(_selectedNeed.reasonKey),
                                  onTap: () => _showTask(focusTask),
                                  onChooseAnother: () => _showJourneyCollection(
                                    _tasksForNeed(catalog, _selectedNeed),
                                    title: copy.ui(_selectedNeed.labelKey),
                                  ),
                                ),
                        );
                        if (constraints.maxWidth >= 900) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: focus),
                              const SizedBox(width: 20),
                              Expanded(flex: 4, child: status),
                            ],
                          );
                        }
                        return Column(
                          children: [focus, const SizedBox(height: 16), status],
                        );
                      },
                    ),
                    const SizedBox(height: 38),
                    _BelongingPath(
                      catalog: catalog,
                      passport: widget.passport,
                      settlement: widget.settlement,
                      onOpenChapter: (definition, tasks) =>
                          _showJourneyCollection(
                            tasks,
                            title: copy.ui(definition.titleKey),
                            body: copy.ui(definition.bodyKey),
                          ),
                    ),
                    const SizedBox(height: 34),
                    _EssentialsSetup(
                      settlement: widget.settlement,
                      onSetBins: _setUpBinNight,
                      onSetLibrary: _setUpLibraryCard,
                      onSetTransport: _setUpTransport,
                      onSetCouncilReport: _setUpCouncilReport,
                      onSetPet: _setUpPet,
                    ),
                    const SizedBox(height: 30),
                    _WholeJourneyInvitation(
                      completed: completed,
                      total: catalog.tasks.length,
                      onTap: () => _showJourneyCollection(catalog.tasks),
                    ),
                    if (widget.onFinishTutorial != null) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: widget.onFinishTutorial,
                          icon: const Icon(Icons.explore_rounded),
                          label: Text(copy.ui('continueExplore')),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Center(
                      child: Text(
                        copy.message('guidanceReviewed', {
                          'date': _formatDate(catalog.lastReviewed),
                        }),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppThemeColors.subtleText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<NewcomerJourneyTask> _tasksForNeed(
    NewcomerJourneyCatalog catalog,
    _JourneyNeed need,
  ) {
    final byId = {for (final task in catalog.tasks) task.id: task};
    return need.taskIds
        .map((id) => byId[id])
        .whereType<NewcomerJourneyTask>()
        .toList(growable: false);
  }

  NewcomerJourneyTask? _focusTask(
    NewcomerJourneyCatalog catalog,
    _JourneyNeed need,
  ) {
    final candidates = _tasksForNeed(catalog, need);
    for (final task in candidates) {
      if (!_isTaskComplete(widget.passport, task, widget.settlement)) {
        return task;
      }
    }
    for (final task in catalog.tasks) {
      if (!_isTaskComplete(widget.passport, task, widget.settlement)) {
        return task;
      }
    }
    return null;
  }

  Future<void> _showJourneyCollection(
    List<NewcomerJourneyTask> tasks, {
    String? title,
    String? body,
  }) async {
    final selected = await showModalBottomSheet<NewcomerJourneyTask>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (sheetContext) => _JourneyCollectionSheet(
        title: title,
        body: body,
        tasks: tasks,
        passport: widget.passport,
        settlement: widget.settlement,
        onSelected: (task) => Navigator.of(sheetContext).pop(task),
      ),
    );
    if (!mounted || selected == null) return;
    await _showTask(selected);
  }

  Future<void> _showTask(NewcomerJourneyTask task) async {
    if (task.id == 'find-bin-day') {
      await _setUpBinNight();
      return;
    }
    if (task.id == 'discover-library') {
      await _setUpLibraryCard(points: task.xp);
      return;
    }
    if (task.id == 'plan-first-trip') {
      await _setUpTransport();
      return;
    }
    final completed = _isTaskComplete(widget.passport, task, widget.settlement);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (sheetContext) => _TaskSheet(
        task: task,
        completed: completed,
        saving: _savingTaskId == task.id,
        onOpen: () {
          Navigator.of(sheetContext).pop();
          _openTask(task);
        },
        onScan:
            task.verification == JourneyVerification.qr &&
                widget.onOpenScanner != null
            ? () {
                Navigator.of(sheetContext).pop();
                widget.onOpenScanner!();
              }
            : null,
        onComplete: task.canSelfComplete && !completed
            ? () async {
                Navigator.of(sheetContext).pop();
                await _completeLearningTask(task);
              }
            : null,
      ),
    );
  }

  Future<void> _setUpBinNight() async {
    final result = await showModalBottomSheet<({int weekday, bool reminder})>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BinSetupSheet(settlement: widget.settlement),
    );
    if (result == null) return;
    await _saveBinNight(result);
  }

  Future<void> _saveBinNight(({int weekday, bool reminder}) result) async {
    if (_savingTaskId != null) return;
    setState(() => _savingTaskId = 'find-bin-day');
    final copy = JourneyLocalizations.of(context);
    var reminderEnabled = result.reminder;
    try {
      if (reminderEnabled) {
        reminderEnabled = await BinNotificationService.instance
            .scheduleWeeklyReminder(
              collectionWeekday: result.weekday,
              title: copy.ui('binNotificationTitle'),
              body: copy.ui('binNotificationBody'),
              channelName: copy.ui('binNotificationChannel'),
              channelDescription: copy.ui('binNotificationChannelDescription'),
            );
      } else {
        await BinNotificationService.instance.cancelReminder();
      }
      await widget.settlement.saveBinCollection(
        weekday: result.weekday,
        reminderEnabled: reminderEnabled,
      );
      await _recordPracticalStep(
        id: 'find-bin-day',
        title: copy.ui('binActivityTitle'),
        body: copy.message('binActivityBody', {
          'day': copy.weekday(result.weekday),
        }),
        localizationArgs: {'weekday': '${result.weekday}'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reminderEnabled
                ? copy.ui('binReminderSaved')
                : copy.ui('binDaySaved'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingTaskId = null);
    }
  }

  Future<void> _setUpLibraryCard({int points = 40}) async {
    final label = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _LibrarySetupSheet(initialValue: widget.settlement.libraryCardLabel),
    );
    if (label == null) return;
    await _saveLibraryCard(label, points: points);
  }

  Future<void> _saveLibraryCard(String label, {int points = 40}) async {
    if (_savingTaskId != null) return;
    setState(() => _savingTaskId = 'discover-library');
    final copy = JourneyLocalizations.of(context);
    try {
      await widget.settlement.saveLibraryCard(label);
      await _recordPracticalStep(
        id: 'discover-library',
        title: copy.ui('libraryActivityTitle'),
        body: copy.ui('libraryActivityBody'),
        badgeId: 'library_local',
        points: points,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.ui('librarySaved'))));
    } finally {
      if (mounted) setState(() => _savingTaskId = null);
    }
  }

  Future<void> _setUpTransport() async {
    final result = await showModalBottomSheet<({String stop, String mode})>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransportSetupSheet(settlement: widget.settlement),
    );
    if (result == null) return;
    await _saveTransport(result);
  }

  Future<void> _saveTransport(({String stop, String mode}) result) async {
    if (_savingTaskId != null) return;
    setState(() => _savingTaskId = 'plan-first-trip');
    final copy = JourneyLocalizations.of(context);
    try {
      await widget.settlement.saveTransportShortcut(
        stop: result.stop,
        mode: result.mode,
      );
      await _recordPracticalStep(
        id: 'plan-first-trip',
        title: copy.ui('transportActivityTitle'),
        body: copy.message('transportActivityBody', {
          'stop': result.stop,
          'mode': copy.transportMode(result.mode),
        }),
        localizationArgs: {'stop': result.stop, 'mode': result.mode},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.ui('transportSaved'))));
    } finally {
      if (mounted) setState(() => _savingTaskId = null);
    }
  }

  Future<void> _setUpCouncilReport() async {
    final copy = JourneyLocalizations.of(context);
    final result =
        await showModalBottomSheet<({String reference, String type})>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              _CouncilReportSheet(settlement: widget.settlement),
        );
    if (result == null) return;
    await widget.settlement.saveCouncilReport(
      reference: result.reference,
      type: result.type,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copy.ui('councilSaved'))));
  }

  Future<void> _setUpPet() async {
    final copy = JourneyLocalizations.of(context);
    final name = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _PetSetupSheet(initialValue: widget.settlement.petName),
    );
    if (name == null) return;
    await widget.settlement.savePetProfile(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copy.message('petSaved', {'name': name}))),
    );
  }

  Future<void> _recordPracticalStep({
    required String id,
    required String title,
    required String body,
    String badgeId = 'civic_ready',
    int points = 0,
    Map<String, String> localizationArgs = const <String, String>{},
  }) async {
    await widget.passport.recordActivity(
      activityId: 'journey:$id',
      placeName: title,
      points: points,
      badgeId: badgeId,
      content: PassportQrContent(
        title: title,
        body: body,
        category: JourneyLocalizations.of(context).ui('localEssentials'),
        localizationId: 'journey.practical:$id',
        localizationArgs: localizationArgs,
      ),
    );
  }

  Future<void> _openTask(NewcomerJourneyTask task) async {
    final destination = task.destination;
    if (destination == 'services' && widget.onOpenServices != null) {
      widget.onOpenServices!();
      return;
    }
    if (destination == 'explore' && widget.onOpenExplore != null) {
      widget.onOpenExplore!();
      return;
    }
    if (destination == 'community' && widget.onOpenCommunity != null) {
      widget.onOpenCommunity!();
      return;
    }
    if (destination == 'scan' && widget.onOpenScanner != null) {
      widget.onOpenScanner!();
      return;
    }
    final url = task.officialUrl;
    if (url == null) return;
    final opened = await const ExternalLinkService().open(url);
    if (!opened && mounted) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(JourneyLocalizations.of(context).ui('linkCopied')),
        ),
      );
    }
  }

  Future<void> _completeLearningTask(NewcomerJourneyTask task) async {
    if (_savingTaskId != null) return;
    setState(() => _savingTaskId = task.id);
    try {
      final copy = JourneyLocalizations.of(context);
      final result = await widget.passport.recordActivity(
        activityId: task.activityId,
        placeName: task.title,
        points: task.xp,
        badgeId: task.badgeId,
        content: PassportQrContent(
          title: task.title,
          body: task.summary,
          category: task.section,
          officialUrl: task.officialUrl,
          localizationId: 'journey.task:${task.id}',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.badgeJustEarned
                ? copy.message('badgeCompleted', {
                    'badge':
                        result.badge?.localizedName(copy.languageCode) ??
                        'Passport',
                  })
                : copy.ui('journeySavedMessage'),
          ),
        ),
      );
    } on Object catch (error) {
      debugPrint('Journey completion error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(JourneyLocalizations.of(context).ui('saveError')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingTaskId = null);
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: AppThemeColors.accentGreen,
            fontSize: 10,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppThemeColors.text,
            height: 1.1,
            letterSpacing: -0.35,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            body,
            style: TextStyle(color: AppThemeColors.subtleText, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _JourneyNeedPicker extends StatelessWidget {
  const _JourneyNeedPicker({required this.selected, required this.onSelected});

  final _JourneyNeed selected;
  final ValueChanged<_JourneyNeed> onSelected;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780 ? 4 : 2;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final need in _JourneyNeed.values)
              SizedBox(
                width: width,
                child: _JourneyNeedChoice(
                  need: need,
                  label: copy.ui(need.labelKey),
                  selected: need == selected,
                  onTap: () => onSelected(need),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _JourneyNeedChoice extends StatelessWidget {
  const _JourneyNeedChoice({
    required this.need,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final _JourneyNeed need;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = _needColor(need);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: selected
                  ? colour.withValues(
                      alpha: AppThemeColors.isDark ? 0.25 : 0.11,
                    )
                  : AppThemeColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? colour : AppThemeColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: selected ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(need.icon, color: colour, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppThemeColors.text,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: colour, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionPulse extends StatelessWidget {
  const _ConnectionPulse({
    required this.completed,
    required this.total,
    required this.setupCount,
    required this.moments,
    required this.latestMoment,
    required this.onOpenWholeJourney,
  });

  final int completed;
  final int total;
  final int setupCount;
  final int moments;
  final String? latestMoment;
  final VoidCallback onOpenWholeJourney;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    final messageKey = completed == 0
        ? 'pulseStart'
        : completed == total
        ? 'pulseComplete'
        : completed < total / 2
        ? 'pulseGrowing'
        : 'pulseBelonging';
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: AppThemeColors.surfaceAlt,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppThemeColors.accentGreen.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: AppThemeColors.accentGreen,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  copy.ui('connectionPulse'),
                  style: TextStyle(
                    color: AppThemeColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            copy.ui(messageKey),
            style: TextStyle(
              color: AppThemeColors.subtleText,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _PulseMetric(
                  value: '$completed',
                  label: copy.ui('familiarMoments'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PulseMetric(
                  value: '$setupCount',
                  label: copy.ui('localTools'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PulseMetric(
                  value: '$moments',
                  label: copy.ui('passportStories'),
                ),
              ),
            ],
          ),
          if (latestMoment case final moment?) ...[
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppThemeColors.surface,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 18,
                    color: AppThemeColors.accentBlue,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.ui('recentMoment').toUpperCase(),
                          style: TextStyle(
                            color: AppThemeColors.muted,
                            fontSize: 9,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          moment,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppThemeColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 9),
          TextButton.icon(
            onPressed: onOpenWholeJourney,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(copy.ui('seeWholeJourney')),
          ),
        ],
      ),
    );
  }
}

class _PulseMetric extends StatelessWidget {
  const _PulseMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppThemeColors.text,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppThemeColors.subtleText,
            fontSize: 9.5,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _JourneyCompleteCard extends StatelessWidget {
  const _JourneyCompleteCard({super.key, required this.onExplore});

  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007D59), Color(0xFF07566B)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.celebration_rounded, color: Color(0xFFFFD28A)),
          const SizedBox(height: 18),
          Text(
            copy.ui('completeCompanionTitle'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            copy.ui('completeCompanionBody'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.5,
            ),
          ),
          if (onExplore != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onExplore,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF07566B),
              ),
              icon: const Icon(Icons.explore_rounded),
              label: Text(copy.ui('continueExplore')),
            ),
          ],
        ],
      ),
    );
  }
}

class _BelongingPath extends StatelessWidget {
  const _BelongingPath({
    required this.catalog,
    required this.passport,
    required this.settlement,
    required this.onOpenChapter,
  });

  final NewcomerJourneyCatalog catalog;
  final PassportController passport;
  final SettlementProfileController settlement;
  final void Function(
    _JourneyChapterDefinition definition,
    List<NewcomerJourneyTask> tasks,
  )
  onOpenChapter;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    final byId = {for (final task in catalog.tasks) task.id: task};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          eyebrow: copy.ui('belongingEyebrow'),
          title: copy.ui('belongingTitle'),
          body: copy.ui('belongingBody'),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var index = 0; index < _journeyChapters.length; index++)
                  Builder(
                    builder: (context) {
                      final definition = _journeyChapters[index];
                      final tasks = definition.taskIds
                          .map((id) => byId[id])
                          .whereType<NewcomerJourneyTask>()
                          .toList(growable: false);
                      final completed = tasks
                          .where(
                            (task) =>
                                _isTaskComplete(passport, task, settlement),
                          )
                          .length;
                      return SizedBox(
                        width: width,
                        child: _ChapterNode(
                          index: index,
                          definition: definition,
                          completed: completed,
                          total: tasks.length,
                          onTap: () => onOpenChapter(definition, tasks),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ChapterNode extends StatelessWidget {
  const _ChapterNode({
    required this.index,
    required this.definition,
    required this.completed,
    required this.total,
    required this.onTap,
  });

  final int index;
  final _JourneyChapterDefinition definition;
  final int completed;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    final complete = total > 0 && completed == total;
    final started = completed > 0;
    final status = complete
        ? copy.ui('rooted')
        : started
        ? copy.ui('growing')
        : copy.ui('readyWhenYouAre');
    return Semantics(
      button: true,
      label: '${copy.ui(definition.titleKey)}, $status',
      child: Material(
        color: AppThemeColors.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 205),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: definition.colour.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          complete ? Icons.check_rounded : definition.icon,
                          color: definition.colour,
                          size: 21,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '0${index + 1}',
                        style: TextStyle(
                          color: AppThemeColors.muted,
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    copy.ui(definition.titleKey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppThemeColors.text,
                      fontSize: 16,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    copy.ui(definition.bodyKey),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppThemeColors.subtleText,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : completed / total,
                            minHeight: 5,
                            backgroundColor: AppThemeColors.border,
                            color: definition.colour,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: definition.colour,
                        size: 17,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    status,
                    style: TextStyle(
                      color: definition.colour,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.value,
    required this.label,
    required this.colour,
  });

  final String value;
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: colour,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppThemeColors.subtleText,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WholeJourneyInvitation extends StatelessWidget {
  const _WholeJourneyInvitation({
    required this.completed,
    required this.total,
    required this.onTap,
  });

  final int completed;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return Material(
      color: AppThemeColors.surfaceStrong,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppThemeColors.accentBlue.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: AppThemeColors.accentBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.ui('seeWholeJourney'),
                      style: TextStyle(
                        color: AppThemeColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.message('wholeJourneyProgress', {
                        'completed': completed,
                        'total': total,
                      }),
                      style: TextStyle(
                        color: AppThemeColors.subtleText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: AppThemeColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyCollectionSheet extends StatelessWidget {
  const _JourneyCollectionSheet({
    required this.title,
    required this.body,
    required this.tasks,
    required this.passport,
    required this.settlement,
    required this.onSelected,
  });

  final String? title;
  final String? body;
  final List<NewcomerJourneyTask> tasks;
  final PassportController passport;
  final SettlementProfileController settlement;
  final ValueChanged<NewcomerJourneyTask> onSelected;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    final grouped = <String, List<NewcomerJourneyTask>>{};
    for (final task in tasks) {
      grouped.putIfAbsent(task.section, () => []).add(task);
    }
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Material(
        color: AppThemeColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppThemeColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title ?? copy.ui('wholeJourneyTitle'),
                              style: TextStyle(
                                color: AppThemeColors.text,
                                fontSize: 23,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              body ?? copy.ui('wholeJourneyBody'),
                              style: TextStyle(
                                color: AppThemeColors.subtleText,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppThemeColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 30),
                children: [
                  for (final entry in grouped.entries) ...[
                    if (entry.key == 'Australian water safety')
                      const _WaterSafetyPrimer(),
                    _JourneySection(
                      title: entry.key,
                      tasks: entry.value,
                      passport: passport,
                      settlement: settlement,
                      savingTaskId: null,
                      onTap: onSelected,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextJourneyStep extends StatelessWidget {
  const _NextJourneyStep({
    super.key,
    required this.task,
    required this.completed,
    required this.reason,
    required this.onTap,
    required this.onChooseAnother,
  });

  final NewcomerJourneyTask task;
  final bool completed;
  final String reason;
  final VoidCallback onTap;
  final VoidCallback onChooseAnother;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    final colour = _kindColor(task.kind);
    return Semantics(
      button: true,
      label: '${copy.ui('nextTitle')}: ${copy.title(task)}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D4F7C), Color(0xFF063A59)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D4F7C).withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF8FF5D1,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: Color(0xFF8FF5D1),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              copy.ui('rightNow').toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF8FF5D1),
                                fontSize: 10,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colour.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(_kindIcon(task.kind), color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    copy.title(task),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.08,
                      letterSpacing: -0.45,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    copy.summary(task),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 14,
                      height: 1.48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          size: 18,
                          color: Color(0xFFFFCA80),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF8FF5D1),
                          foregroundColor: const Color(0xFF063A59),
                        ),
                        icon: Icon(
                          completed
                              ? Icons.replay_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(
                          completed
                              ? copy.ui('revisitStep')
                              : copy.action(task),
                        ),
                      ),
                      TextButton(
                        onPressed: onChooseAnother,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: Text(copy.ui('chooseAnother')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EssentialsSetup extends StatelessWidget {
  const _EssentialsSetup({
    required this.settlement,
    required this.onSetBins,
    required this.onSetLibrary,
    required this.onSetTransport,
    required this.onSetCouncilReport,
    required this.onSetPet,
  });

  final SettlementProfileController settlement;
  final VoidCallback onSetBins;
  final VoidCallback onSetLibrary;
  final VoidCallback onSetTransport;
  final VoidCallback onSetCouncilReport;
  final VoidCallback onSetPet;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    final actions = <Widget>[
      _SetupAction(
        icon: Icons.delete_outline_rounded,
        title: copy.ui('binCollection'),
        value: settlement.hasBinDay
            ? '${copy.weekday(settlement.binCollectionWeekday!)} · '
                  '${copy.ui(settlement.binReminderEnabled ? 'reminderOn' : 'reminderOff')}'
            : copy.ui('confirmCollectionDay'),
        complete: settlement.hasBinDay,
        onTap: onSetBins,
      ),
      _SetupAction(
        icon: Icons.local_library_rounded,
        title: copy.ui('libraryMembership'),
        value: settlement.libraryCardLabel ?? copy.ui('joinSaveCard'),
        complete: settlement.hasLibraryCard,
        onTap: onSetLibrary,
      ),
      _SetupAction(
        icon: Icons.directions_transit_rounded,
        title: copy.ui('usualStop'),
        value: settlement.hasTransportShortcut
            ? '${settlement.transportStop} · '
                  '${copy.transportMode(settlement.transportMode!)}'
            : copy.ui('saveStop'),
        complete: settlement.hasTransportShortcut,
        onTap: onSetTransport,
      ),
      _SetupAction(
        icon: Icons.report_outlined,
        title: copy.ui('councilTracker'),
        value: settlement.hasCouncilReport
            ? '${_localizedCouncilIssueType(copy, settlement.councilReportType)} · '
                  '${settlement.councilReportReference}'
            : copy.ui('keepReport'),
        complete: settlement.hasCouncilReport,
        onTap: onSetCouncilReport,
      ),
      _SetupAction(
        icon: Icons.pets_rounded,
        title: copy.ui('petGuide'),
        value: settlement.hasPetProfile
            ? copy.message('petStatus', {'name': settlement.petName!})
            : copy.ui('addPet'),
        complete: settlement.hasPetProfile,
        onTap: onSetPet,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SectionHeading(
                eyebrow: copy.ui('toolkitEyebrow'),
                title: copy.ui('toolkitTitle'),
                body: copy.ui('toolkitBody'),
              ),
            ),
            const SizedBox(width: 12),
            _CountPill(
              value: '${settlement.usefulToolCount}',
              label: copy.ui('anchorsReady'),
              colour: AppThemeColors.accentGreen,
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 880 ? 3 : 2;
            final spacing = 12.0;
            final tileWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final action in actions)
                  SizedBox(width: tileWidth, child: action),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SetupAction extends StatelessWidget {
  const _SetupAction({
    required this.icon,
    required this.title,
    required this.value,
    required this.complete,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = complete
        ? AppThemeColors.accentGreen
        : AppThemeColors.accentBlue;
    return Semantics(
      button: true,
      label: '$title, $value',
      child: Material(
        color: AppThemeColors.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 148),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colour.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          complete ? Icons.check_rounded : icon,
                          color: colour,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        complete ? Icons.edit_rounded : Icons.add_rounded,
                        color: AppThemeColors.muted,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppThemeColors.text,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppThemeColors.subtleText,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BinSetupSheet extends StatefulWidget {
  const _BinSetupSheet({required this.settlement});

  final SettlementProfileController settlement;

  @override
  State<_BinSetupSheet> createState() => _BinSetupSheetState();
}

class _BinSetupSheetState extends State<_BinSetupSheet> {
  late int _weekday = widget.settlement.binCollectionWeekday ?? DateTime.monday;
  late bool _reminder = widget.settlement.binReminderEnabled;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return _SetupSheetFrame(
      icon: Icons.delete_outline_rounded,
      title: copy.ui('binSheetTitle'),
      body: copy.ui('binSheetBody'),
      children: [
        OutlinedButton.icon(
          onPressed: () => const ExternalLinkService().open(
            'https://www.canadabay.nsw.gov.au/residents/waste-and-recycling/my-bins',
          ),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(copy.ui('binLookup')),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _weekday,
          decoration: InputDecoration(labelText: copy.ui('collectionDay')),
          items: [
            for (var weekday = 1; weekday <= 7; weekday++)
              DropdownMenuItem(
                value: weekday,
                child: Text(copy.weekday(weekday)),
              ),
          ],
          onChanged: (value) => setState(() => _weekday = value ?? _weekday),
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _reminder,
          onChanged: (value) => setState(() => _reminder = value),
          title: Text(copy.ui('remindNightBefore')),
          subtitle: Text(copy.ui('weeklyAtSix')),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, (
              weekday: _weekday,
              reminder: _reminder,
            )),
            child: Text(copy.ui('savePassport')),
          ),
        ),
      ],
    );
  }
}

class _LibrarySetupSheet extends StatefulWidget {
  const _LibrarySetupSheet({this.initialValue});

  final String? initialValue;

  @override
  State<_LibrarySetupSheet> createState() => _LibrarySetupSheetState();
}

class _LibrarySetupSheetState extends State<_LibrarySetupSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return _SetupSheetFrame(
      icon: Icons.local_library_rounded,
      title: copy.ui('librarySheetTitle'),
      body: copy.ui('librarySheetBody'),
      children: [
        OutlinedButton.icon(
          onPressed: () => const ExternalLinkService().open(
            'https://www.canadabay.nsw.gov.au/libraries/Membership',
          ),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(copy.ui('openLibrary')),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: copy.ui('cardLabel'),
            hintText: copy.ui('cardHint'),
          ),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 8),
        Text(
          copy.ui('libraryPrivacy'),
          style: TextStyle(
            color: AppThemeColors.subtleText,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final value = _controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: Text(copy.ui('savePassport')),
          ),
        ),
      ],
    );
  }
}

class _TransportSetupSheet extends StatefulWidget {
  const _TransportSetupSheet({required this.settlement});

  final SettlementProfileController settlement;

  @override
  State<_TransportSetupSheet> createState() => _TransportSetupSheetState();
}

class _TransportSetupSheetState extends State<_TransportSetupSheet> {
  late final TextEditingController _stopController = TextEditingController(
    text: widget.settlement.transportStop,
  );
  late String _mode = widget.settlement.transportMode ?? 'Train';

  @override
  void dispose() {
    _stopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return _SetupSheetFrame(
      icon: Icons.directions_transit_rounded,
      title: copy.ui('transportSheetTitle'),
      body: copy.ui('transportSheetBody'),
      children: [
        OutlinedButton.icon(
          onPressed: () => const ExternalLinkService().open(
            'https://transportnsw.info/trip',
          ),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(copy.ui('openTransport')),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _mode,
          decoration: InputDecoration(labelText: copy.ui('travelMode')),
          items: [
            for (final mode in const [
              'Train',
              'Bus',
              'Ferry',
              'Light rail',
              'Bike',
              'Walk',
            ])
              DropdownMenuItem(
                value: mode,
                child: Text(copy.transportMode(mode)),
              ),
          ],
          onChanged: (value) => setState(() => _mode = value ?? _mode),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _stopController,
          decoration: InputDecoration(
            labelText: copy.ui('stopLabel'),
            hintText: copy.ui('stopHint'),
          ),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final stop = _stopController.text.trim();
              if (stop.isNotEmpty) {
                Navigator.pop(context, (stop: stop, mode: _mode));
              }
            },
            child: Text(copy.ui('saveTransport')),
          ),
        ),
      ],
    );
  }
}

class _CouncilReportSheet extends StatefulWidget {
  const _CouncilReportSheet({required this.settlement});

  final SettlementProfileController settlement;

  @override
  State<_CouncilReportSheet> createState() => _CouncilReportSheetState();
}

class _CouncilReportSheetState extends State<_CouncilReportSheet> {
  late final TextEditingController _referenceController = TextEditingController(
    text: widget.settlement.councilReportReference,
  );
  late final TextEditingController _typeController = TextEditingController(
    text:
        SettlementProfileController.isDefaultCouncilIssueType(
          widget.settlement.councilReportType,
        )
        ? null
        : widget.settlement.councilReportType,
  );
  String? _defaultTypeLabel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextDefault = JourneyLocalizations.of(context).ui('councilIssue');
    if (_typeController.text.isEmpty ||
        _typeController.text == _defaultTypeLabel) {
      _typeController.text = nextDefault;
    }
    _defaultTypeLabel = nextDefault;
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return _SetupSheetFrame(
      icon: Icons.report_outlined,
      title: copy.ui('councilSheetTitle'),
      body: copy.ui('councilSheetBody'),
      children: [
        OutlinedButton.icon(
          onPressed: () => const ExternalLinkService().open(
            'https://cityofcanadabay.snapforms.com.au/form/report-an-issue',
          ),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(copy.ui('openReport')),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _typeController,
          decoration: InputDecoration(
            labelText: copy.ui('reportTypeLabel'),
            hintText: copy.ui('reportTypeHint'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _referenceController,
          decoration: InputDecoration(
            labelText: copy.ui('reportReferenceLabel'),
            hintText: copy.ui('reportReferenceHint'),
          ),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 8),
        Text(
          copy.ui('reportPrivacy'),
          style: TextStyle(
            color: AppThemeColors.subtleText,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final reference = _referenceController.text.trim();
              final type = _typeController.text.trim();
              if (reference.isNotEmpty && type.isNotEmpty) {
                Navigator.pop(context, (
                  reference: reference,
                  type: type == copy.ui('councilIssue')
                      ? SettlementProfileController.defaultCouncilIssueType
                      : type,
                ));
              }
            },
            child: Text(copy.ui('saveReport')),
          ),
        ),
      ],
    );
  }
}

class _PetSetupSheet extends StatefulWidget {
  const _PetSetupSheet({this.initialValue});

  final String? initialValue;

  @override
  State<_PetSetupSheet> createState() => _PetSetupSheetState();
}

class _PetSetupSheetState extends State<_PetSetupSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return _SetupSheetFrame(
      icon: Icons.pets_rounded,
      title: copy.ui('petSheetTitle'),
      body: copy.ui('petSheetBody'),
      children: [
        OutlinedButton.icon(
          onPressed: () => const ExternalLinkService().open(
            'https://www.canadabay.nsw.gov.au/residents/animals/local-off-leash-areas',
          ),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(copy.ui('viewOffLeash')),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: copy.ui('petNameLabel'),
            hintText: copy.ui('petNameHint'),
          ),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final name = _controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(context, name);
            },
            child: Text(copy.ui('addPetPassport')),
          ),
        ),
      ],
    );
  }
}

class _SetupSheetFrame extends StatelessWidget {
  const _SetupSheetFrame({
    required this.icon,
    required this.title,
    required this.body,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppThemeColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppThemeColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Icon(icon, color: AppThemeColors.accentGreen, size: 30),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: AppThemeColors.text,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    color: AppThemeColors.subtleText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyTutorialHeader extends StatelessWidget {
  const _JourneyTutorialHeader({
    required this.title,
    required this.pageLabel,
    required this.progress,
    required this.onOverview,
    required this.overviewTooltip,
  });

  final String title;
  final String pageLabel;
  final double progress;
  final VoidCallback onOverview;
  final String overviewTooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        border: Border(bottom: BorderSide(color: AppThemeColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppThemeColors.accentGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppThemeColors.accentGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppThemeColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pageLabel,
                      style: TextStyle(
                        color: AppThemeColors.subtleText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('journey-overview-button'),
                tooltip: overviewTooltip,
                onPressed: onOverview,
                icon: const Icon(Icons.dashboard_customize_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: AppThemeColors.surfaceStrong,
              color: AppThemeColors.accentGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyTutorialIntro extends StatelessWidget {
  const _JourneyTutorialIntro({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    const features = <(String, IconData)>[
      ('featureHome', Icons.home_rounded),
      ('featureExplore', Icons.explore_rounded),
      ('featureCommunity', Icons.groups_rounded),
      ('featureServices', Icons.home_work_rounded),
      ('featurePassport', Icons.auto_stories_rounded),
      ('featureScan', Icons.qr_code_scanner_rounded),
      ('featureProfile', Icons.person_rounded),
    ];

    return SingleChildScrollView(
      key: const ValueKey('journey-tutorial-intro'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppThemeColors.accentGreen.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  copy.ui('tutorialEyebrow'),
                  style: TextStyle(
                    color: AppThemeColors.accentGreen,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                copy.ui('tutorialIntroTitle'),
                style: TextStyle(
                  color: AppThemeColors.text,
                  fontSize: MediaQuery.sizeOf(context).width < 600 ? 31 : 42,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                copy.ui('tutorialIntroBody'),
                style: TextStyle(
                  color: AppThemeColors.muted,
                  fontSize: 15,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D4F7C), Color(0xFF08745F)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.ui('tutorialAppTour'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final feature in features)
                          _JourneyFeatureChip(
                            icon: feature.$2,
                            label: copy.ui(feature.$1),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _JourneyTutorialNotice(
                icon: Icons.bookmark_added_rounded,
                title: copy.progress(completed, total),
                body: copy.ui('tutorialProgressBody'),
                colour: AppThemeColors.accentGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyFeatureChip extends StatelessWidget {
  const _JourneyFeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
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

class _JourneyTutorialTaskPage extends StatelessWidget {
  const _JourneyTutorialTaskPage({
    super.key,
    required this.day,
    required this.task,
    required this.completed,
    required this.saving,
    required this.featureKey,
    required this.storageKey,
    required this.icon,
    required this.colour,
    required this.onOpen,
    this.inlineSetup,
    this.onScan,
    this.onComplete,
  });

  final int day;
  final NewcomerJourneyTask task;
  final bool completed;
  final bool saving;
  final String featureKey;
  final String storageKey;
  final IconData icon;
  final Color colour;
  final VoidCallback onOpen;
  final Widget? inlineSetup;
  final VoidCallback? onScan;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    final contextNote = copy.contextNote(task.id);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colour.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      copy.message('tutorialDay', {'day': day}),
                      style: TextStyle(
                        color: colour,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      copy.section(task.section).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppThemeColors.subtleText,
                        fontSize: 9.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (completed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppThemeColors.accentGreen.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppThemeColors.accentGreen,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            copy.ui('completed'),
                            style: TextStyle(
                              color: AppThemeColors.accentGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: colour.withValues(alpha: 0.25),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 20),
              Text(
                copy.title(task),
                style: TextStyle(
                  color: AppThemeColors.text,
                  fontSize: MediaQuery.sizeOf(context).width < 600 ? 28 : 36,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                copy.summary(task),
                style: TextStyle(
                  color: AppThemeColors.muted,
                  fontSize: 14.5,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (contextNote != null) ...[
                const SizedBox(height: 16),
                _JourneyTutorialNotice(
                  icon: Icons.lightbulb_rounded,
                  title: copy.ui('contextHeading'),
                  body: contextNote,
                  colour: const Color(0xFFD08A22),
                ),
              ],
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    _JourneyTutorialInfoCard(
                      icon: Icons.apps_rounded,
                      eyebrow: copy.ui('tutorialInApp'),
                      value: copy.ui(featureKey),
                      colour: colour,
                    ),
                    _JourneyTutorialInfoCard(
                      icon: Icons.bookmark_added_rounded,
                      eyebrow: copy.ui('tutorialSavedIn'),
                      value: copy.ui(storageKey),
                      colour: AppThemeColors.accentGreen,
                    ),
                  ];
                  if (constraints.maxWidth >= 620) {
                    return Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                      ],
                    );
                  }
                  return Column(
                    children: [cards[0], const SizedBox(height: 10), cards[1]],
                  );
                },
              ),
              const SizedBox(height: 11),
              _JourneyTutorialInfoCard(
                icon: Icons.verified_rounded,
                eyebrow: copy.ui('tutorialHowComplete'),
                value: copy.verification(task),
                colour: const Color(0xFF8E68C7),
              ),
              const SizedBox(height: 20),
              if (inlineSetup != null)
                inlineSetup!
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: ValueKey('journey-task-open:${task.id}'),
                    onPressed: onOpen,
                    style: FilledButton.styleFrom(
                      backgroundColor: colour,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_outward_rounded),
                    label: Text(
                      copy.action(task),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              if (onScan != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onScan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(copy.ui('featureScan')),
                  ),
                ),
              ],
              if (onComplete != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: ValueKey('journey-task-complete:${task.id}'),
                    onPressed: saving ? null : onComplete,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(copy.ui('understandGuidance')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialBinSetup extends StatefulWidget {
  const _TutorialBinSetup({
    required this.settlement,
    required this.saving,
    required this.onSave,
  });

  final SettlementProfileController settlement;
  final bool saving;
  final Future<void> Function(({int weekday, bool reminder})) onSave;

  @override
  State<_TutorialBinSetup> createState() => _TutorialBinSetupState();
}

class _TutorialBinSetupState extends State<_TutorialBinSetup> {
  late int _weekday = widget.settlement.binCollectionWeekday ?? DateTime.monday;
  late bool _reminder = widget.settlement.binReminderEnabled;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return _TutorialSetupCard(
      icon: Icons.delete_outline_rounded,
      title: copy.ui('binSheetTitle'),
      body: copy.ui('binSheetBody'),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => const ExternalLinkService().open(
                'https://www.canadabay.nsw.gov.au/residents/waste-and-recycling/my-bins',
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(copy.ui('binLookup')),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _weekday,
            decoration: InputDecoration(labelText: copy.ui('collectionDay')),
            items: [
              for (var weekday = 1; weekday <= 7; weekday++)
                DropdownMenuItem(
                  value: weekday,
                  child: Text(copy.weekday(weekday)),
                ),
            ],
            onChanged: widget.saving
                ? null
                : (value) => setState(() => _weekday = value ?? _weekday),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _reminder,
            onChanged: widget.saving
                ? null
                : (value) => setState(() => _reminder = value),
            title: Text(copy.ui('remindNightBefore')),
            subtitle: Text(copy.ui('weeklyAtSix')),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('tutorial-save-bin-night'),
              onPressed: widget.saving
                  ? null
                  : () =>
                        widget.onSave((weekday: _weekday, reminder: _reminder)),
              icon: widget.saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_done_rounded),
              label: Text(copy.ui('savePassport')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialLibrarySetup extends StatefulWidget {
  const _TutorialLibrarySetup({
    required this.initialValue,
    required this.saving,
    required this.onSave,
  });

  final String? initialValue;
  final bool saving;
  final Future<void> Function(String) onSave;

  @override
  State<_TutorialLibrarySetup> createState() => _TutorialLibrarySetupState();
}

class _TutorialLibrarySetupState extends State<_TutorialLibrarySetup> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return _TutorialSetupCard(
      icon: Icons.local_library_rounded,
      title: copy.ui('librarySheetTitle'),
      body: copy.ui('librarySheetBody'),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => const ExternalLinkService().open(
                'https://www.canadabay.nsw.gov.au/libraries/Membership',
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(copy.ui('openLibrary')),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            enabled: !widget.saving,
            decoration: InputDecoration(
              labelText: copy.ui('cardLabel'),
              hintText: copy.ui('cardHint'),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 7),
          Text(
            copy.ui('libraryPrivacy'),
            style: TextStyle(
              color: AppThemeColors.subtleText,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('tutorial-save-library'),
              onPressed: widget.saving
                  ? null
                  : () {
                      final value = _controller.text.trim();
                      if (value.isNotEmpty) widget.onSave(value);
                    },
              icon: widget.saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_done_rounded),
              label: Text(copy.ui('savePassport')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialTransportSetup extends StatefulWidget {
  const _TutorialTransportSetup({
    required this.settlement,
    required this.saving,
    required this.onSave,
  });

  final SettlementProfileController settlement;
  final bool saving;
  final Future<void> Function(({String stop, String mode})) onSave;

  @override
  State<_TutorialTransportSetup> createState() =>
      _TutorialTransportSetupState();
}

class _TutorialTransportSetupState extends State<_TutorialTransportSetup> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.settlement.transportStop,
  );
  late String _mode = widget.settlement.transportMode ?? 'Train';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return _TutorialSetupCard(
      icon: Icons.directions_transit_rounded,
      title: copy.ui('transportSheetTitle'),
      body: copy.ui('transportSheetBody'),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => const ExternalLinkService().open(
                'https://transportnsw.info/trip',
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(copy.ui('openTransport')),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: InputDecoration(labelText: copy.ui('travelMode')),
            items: [
              for (final mode in const [
                'Train',
                'Bus',
                'Ferry',
                'Light rail',
                'Bike',
                'Walk',
              ])
                DropdownMenuItem(
                  value: mode,
                  child: Text(copy.transportMode(mode)),
                ),
            ],
            onChanged: widget.saving
                ? null
                : (value) => setState(() => _mode = value ?? _mode),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            enabled: !widget.saving,
            decoration: InputDecoration(
              labelText: copy.ui('stopLabel'),
              hintText: copy.ui('stopHint'),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('tutorial-save-transport'),
              onPressed: widget.saving
                  ? null
                  : () {
                      final stop = _controller.text.trim();
                      if (stop.isNotEmpty) {
                        widget.onSave((stop: stop, mode: _mode));
                      }
                    },
              icon: widget.saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_done_rounded),
              label: Text(copy.ui('saveTransport')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialSetupCard extends StatelessWidget {
  const _TutorialSetupCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppThemeColors.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppThemeColors.accentGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppThemeColors.accentGreen),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppThemeColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: TextStyle(
              color: AppThemeColors.subtleText,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _JourneyTutorialInfoCard extends StatelessWidget {
  const _JourneyTutorialInfoCard({
    required this.icon,
    required this.eyebrow,
    required this.value,
    required this.colour,
  });

  final IconData icon;
  final String eyebrow;
  final String value;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colour.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: colour, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: TextStyle(
                    color: colour,
                    fontSize: 8.5,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: AppThemeColors.text,
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyTutorialNotice extends StatelessWidget {
  const _JourneyTutorialNotice({
    required this.icon,
    required this.title,
    required this.body,
    required this.colour,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colour, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppThemeColors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: AppThemeColors.muted,
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyTutorialFinish extends StatelessWidget {
  const _JourneyTutorialFinish({
    required this.completed,
    required this.total,
    this.onOpenHome,
    this.onOpenPassport,
    this.onOpenProfile,
  });

  final int completed;
  final int total;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenPassport;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return SingleChildScrollView(
      key: const ValueKey('journey-tutorial-finish'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A477), Color(0xFF1769AA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(29),
                ),
                child: const Icon(
                  Icons.waving_hand_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                copy.ui('completeCompanionTitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppThemeColors.text,
                  fontSize: MediaQuery.sizeOf(context).width < 600 ? 29 : 38,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                copy.ui('completeCompanionBody'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppThemeColors.muted,
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _JourneyTutorialNotice(
                icon: Icons.auto_stories_rounded,
                title: copy.progress(completed, total),
                body: copy.ui('tutorialFinishBody'),
                colour: AppThemeColors.accentGreen,
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 9,
                runSpacing: 9,
                children: [
                  if (onOpenHome != null)
                    OutlinedButton.icon(
                      onPressed: onOpenHome,
                      icon: const Icon(Icons.home_rounded),
                      label: Text(copy.ui('featureHome')),
                    ),
                  if (onOpenPassport != null)
                    OutlinedButton.icon(
                      onPressed: onOpenPassport,
                      icon: const Icon(Icons.auto_stories_rounded),
                      label: Text(copy.ui('featurePassport')),
                    ),
                  if (onOpenProfile != null)
                    OutlinedButton.icon(
                      onPressed: onOpenProfile,
                      icon: const Icon(Icons.person_rounded),
                      label: Text(copy.ui('featureProfile')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyTutorialNavigation extends StatelessWidget {
  const _JourneyTutorialNavigation({
    required this.currentPage,
    required this.totalPages,
    required this.onBack,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    final lastPage = currentPage == totalPages - 1;
    final firstPage = currentPage == 0;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppThemeColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppThemeColors.border),
          boxShadow: [
            BoxShadow(
              color: AppThemeColors.shadow,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton.outlined(
              key: const ValueKey('journey-tutorial-back'),
              tooltip: copy.ui('tutorialBack'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    copy.ui('tutorialSwipeHint'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppThemeColors.subtleText,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: (currentPage + 1) / totalPages,
                      backgroundColor: AppThemeColors.surfaceStrong,
                      color: AppThemeColors.accentBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              key: const ValueKey('journey-tutorial-next'),
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: AppThemeColors.accentGreen,
                foregroundColor: AppThemeColors.isDark
                    ? const Color(0xFF061C31)
                    : Colors.white,
                minimumSize: const Size(112, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(
                lastPage ? Icons.home_rounded : Icons.arrow_forward_rounded,
              ),
              label: Text(
                copy.ui(
                  lastPage
                      ? 'tutorialFinish'
                      : firstPage
                      ? 'tutorialStart'
                      : 'tutorialNext',
                ),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyHero extends StatelessWidget {
  const _JourneyHero({
    required this.completed,
    required this.total,
    required this.progress,
    required this.setupCount,
  });

  final int completed;
  final int total;
  final double progress;
  final int setupCount;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    final headlineKey = completed == 0
        ? 'heroCompanionStart'
        : completed == total
        ? 'heroCompanionComplete'
        : completed < total / 2
        ? 'heroCompanionGrowing'
        : 'heroCompanionBelonging';
    final bodyKey = completed == 0
        ? 'heroCompanionStartBody'
        : completed == total
        ? 'heroCompanionCompleteBody'
        : 'heroCompanionGrowingBody';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D4F7C), Color(0xFF06304A)],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: compact ? -70 : 38,
                top: compact ? 72 : 66,
                child: Container(
                  width: compact ? 190 : 220,
                  height: compact ? 190 : 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF29D3A2).withValues(alpha: 0.07),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: compact ? -20 : 95,
                top: compact ? 118 : 102,
                child: Icon(
                  Icons.people_alt_rounded,
                  size: compact ? 92 : 104,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 22 : 28,
                    68,
                    compact ? 22 : 28,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8FF5D1,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.explore_rounded,
                                  size: 18,
                                  color: Color(0xFF8FF5D1),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  copy.ui('companionHeroLabel').toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF8FF5D1),
                                    fontSize: 10,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: compact ? 335 : 640,
                            ),
                            child: Text(
                              copy.ui(headlineKey),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 30 : 36,
                                height: 1.04,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.9,
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Text(
                              copy.ui(bodyKey),
                              maxLines: compact ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 17),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: progress),
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 650),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, _) =>
                                        LinearProgressIndicator(
                                          value: value,
                                          minHeight: 6,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.14),
                                          color: const Color(0xFF8FF5D1),
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 13),
                              Text(
                                copy.message('heroFamiliarCount', {
                                  'count': completed,
                                }),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(width: 14),
                                Text(
                                  copy.message('essentialsSaved', {
                                    'count': setupCount,
                                  }),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.62),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JourneySection extends StatelessWidget {
  const _JourneySection({
    required this.title,
    required this.tasks,
    required this.passport,
    required this.settlement,
    required this.savingTaskId,
    required this.onTap,
  });

  final String title;
  final List<NewcomerJourneyTask> tasks;
  final PassportController passport;
  final SettlementProfileController settlement;
  final String? savingTaskId;
  final ValueChanged<NewcomerJourneyTask> onTap;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    final completed = tasks
        .where((task) => _isTaskComplete(passport, task, settlement))
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  copy.section(title),
                  style: TextStyle(
                    color: AppThemeColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$completed/${tasks.length}',
                style: TextStyle(
                  color: AppThemeColors.accentGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: AppThemeColors.surface.withValues(alpha: 0.54),
            shape: Border(
              top: BorderSide(color: AppThemeColors.border),
              bottom: BorderSide(color: AppThemeColors.border),
            ),
            child: Column(
              children: [
                for (var index = 0; index < tasks.length; index++) ...[
                  _JourneyTaskRow(
                    task: tasks[index],
                    completed: _isTaskComplete(
                      passport,
                      tasks[index],
                      settlement,
                    ),
                    saving: savingTaskId == tasks[index].id,
                    onTap: () => onTap(tasks[index]),
                  ),
                  if (index != tasks.length - 1)
                    Divider(
                      height: 1,
                      indent: 72,
                      color: AppThemeColors.border,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyTaskRow extends StatelessWidget {
  const _JourneyTaskRow({
    required this.task,
    required this.completed,
    required this.saving,
    required this.onTap,
  });

  final NewcomerJourneyTask task;
  final bool completed;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: completed
            ? AppThemeColors.accentGreen
            : _kindColor(task.kind).withValues(alpha: 0.14),
        foregroundColor: completed ? Colors.white : _kindColor(task.kind),
        child: Icon(completed ? Icons.check_rounded : _kindIcon(task.kind)),
      ),
      title: Text(
        copy.title(task),
        style: TextStyle(
          color: AppThemeColors.text,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          copy.summary(task),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppThemeColors.subtleText, height: 1.35),
        ),
      ),
      trailing: saving
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : completed
          ? Icon(Icons.verified_rounded, color: AppThemeColors.accentGreen)
          : Icon(Icons.chevron_right_rounded, color: AppThemeColors.muted),
    );
  }
}

class _WaterSafetyPrimer extends StatelessWidget {
  const _WaterSafetyPrimer();

  @override
  Widget build(BuildContext context) {
    final localizations = JourneyLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
          child: Container(
            color: const Color(0xFF083B55),
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final flags = const _BeachFlags();
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.ui('waterEyebrow'),
                      style: const TextStyle(
                        color: Color(0xFF8FF5D1),
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations.ui('waterTitle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      localizations.ui('waterBody'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        height: 1.45,
                      ),
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [copy, const SizedBox(height: 20), flags],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: copy),
                    const SizedBox(width: 30),
                    Expanded(flex: 2, child: flags),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BeachFlags extends StatelessWidget {
  const _BeachFlags();

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return Column(
      children: [
        _FlagLine(
          colors: const [Color(0xFFE53935), Color(0xFFFFD54F)],
          label: copy.ui('flagSwimBetween'),
        ),
        const SizedBox(height: 10),
        _FlagLine(colors: const [Color(0xFFE53935)], label: copy.ui('flagRed')),
        const SizedBox(height: 10),
        _FlagLine(
          colors: const [Color(0xFFFFD54F)],
          label: copy.ui('flagYellow'),
        ),
      ],
    );
  }
}

class _FlagLine extends StatelessWidget {
  const _FlagLine({required this.colors, required this.label});

  final List<Color> colors;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors.length == 1
                  ? [colors.first, colors.first]
                  : colors,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskSheet extends StatelessWidget {
  const _TaskSheet({
    required this.task,
    required this.completed,
    required this.saving,
    required this.onOpen,
    required this.onScan,
    required this.onComplete,
  });

  final NewcomerJourneyTask task;
  final bool completed;
  final bool saving;
  final VoidCallback onOpen;
  final VoidCallback? onScan;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return Material(
      color: AppThemeColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  color: AppThemeColors.border,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Icon(_kindIcon(task.kind), color: _kindColor(task.kind)),
                  const SizedBox(width: 9),
                  Text(
                    copy.section(task.section).toUpperCase(),
                    style: TextStyle(
                      color: _kindColor(task.kind),
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                copy.title(task),
                style: TextStyle(
                  color: AppThemeColors.text,
                  fontSize: 26,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                copy.summary(task),
                style: TextStyle(
                  color: AppThemeColors.subtleText,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              if (copy.contextNote(task.id) case final note?) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _kindColor(task.kind).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: _kindColor(task.kind),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              copy.ui('contextHeading'),
                              style: TextStyle(
                                color: AppThemeColors.text,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              note,
                              style: TextStyle(
                                color: AppThemeColors.subtleText,
                                fontSize: 11,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _VerificationLine(task: task, completed: completed),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : onOpen,
                  icon: Icon(
                    completed ? Icons.replay_rounded : _actionIcon(task),
                  ),
                  label: Text(
                    completed ? copy.ui('revisitStep') : copy.action(task),
                  ),
                ),
              ),
              if (onScan != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : onScan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(copy.ui('scanWhenThere')),
                  ),
                ),
              ],
              if (onComplete != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : onComplete,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(copy.ui('understandGuidance')),
                  ),
                ),
              ],
              if (completed)
                Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: AppThemeColors.accentGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      copy.ui('savedPassport'),
                      style: TextStyle(
                        color: AppThemeColors.accentGreen,
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
  }
}

class _VerificationLine extends StatelessWidget {
  const _VerificationLine({required this.task, required this.completed});

  final NewcomerJourneyTask task;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final label = JourneyLocalizations.of(context).verification(task);
    return Row(
      children: [
        Icon(
          completed ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          color: completed ? AppThemeColors.accentGreen : AppThemeColors.muted,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppThemeColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _JourneyError extends StatelessWidget {
  const _JourneyError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = JourneyLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 48, color: AppThemeColors.muted),
            const SizedBox(height: 12),
            Text(
              copy.ui('journeyUnavailable'),
              style: TextStyle(
                color: AppThemeColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(copy.ui('tryAgain'))),
          ],
        ),
      ),
    );
  }
}

String _localizedCouncilIssueType(JourneyLocalizations copy, String? source) =>
    SettlementProfileController.isDefaultCouncilIssueType(source)
    ? copy.ui('councilIssue')
    : source!;

IconData _kindIcon(JourneyTaskKind kind) => switch (kind) {
  JourneyTaskKind.learn => Icons.menu_book_rounded,
  JourneyTaskKind.civic => Icons.account_balance_rounded,
  JourneyTaskKind.explore => Icons.explore_rounded,
  JourneyTaskKind.community => Icons.groups_rounded,
};

Color _kindColor(JourneyTaskKind kind) => switch (kind) {
  JourneyTaskKind.learn => const Color(0xFF22A9D6),
  JourneyTaskKind.civic => const Color(0xFF4F8FDE),
  JourneyTaskKind.explore => const Color(0xFF00B87A),
  JourneyTaskKind.community => const Color(0xFFA47AE8),
};

Color _needColor(_JourneyNeed need) => switch (need) {
  _JourneyNeed.settle => const Color(0xFF3979C7),
  _JourneyNeed.findWay => const Color(0xFF008F73),
  _JourneyNeed.meetPeople => const Color(0xFF8E68C7),
  _JourneyNeed.careTogether => const Color(0xFFD56B42),
};

IconData _actionIcon(NewcomerJourneyTask task) {
  if (task.verification == JourneyVerification.qr) {
    return Icons.qr_code_scanner_rounded;
  }
  if (task.verification == JourneyVerification.route) {
    return Icons.route_rounded;
  }
  return task.officialUrl == null
      ? Icons.arrow_forward_rounded
      : Icons.open_in_new_rounded;
}

bool _isTaskComplete(
  PassportController passport,
  NewcomerJourneyTask task,
  SettlementProfileController settlement,
) {
  if (task.id == 'find-bin-day') return settlement.hasBinDay;
  if (task.id == 'discover-library') return settlement.hasLibraryCard;
  if (task.id == 'plan-first-trip') return settlement.hasTransportShortcut;
  if (task.canSelfComplete) {
    return passport.hasActivity(task.activityId);
  }
  return passport.badgeProgress(task.badgeId) > 0;
}
