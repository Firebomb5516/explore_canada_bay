import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/journey_activity_localizations.dart';
import '../l10n/journey_localizations.dart';
import '../models/community_challenge.dart';
import '../models/passport.dart';
import '../models/settlement_profile.dart';
import '../services/external_link_service.dart';
import '../theme/app_theme.dart';
import '../widgets/localized_text.dart';

const _passportBlue = Color(0xFF0D4F7C);
Color get _passportGreen => AppThemeColors.accentGreen;
Color get _passportDark => AppThemeColors.background;
Color get _passportCardLight => AppThemeColors.surfaceAlt;
Color get _passportText => AppThemeColors.text;
Color get _passportMuted => AppThemeColors.muted;
const _passportAccent = Color(0xFF2179C8);
const _passportOnBrandMuted = Color(0xFF9ED9E5);
const _logoAsset = 'assets/images/canada_bay_logo.jpg';

class PassportScreen extends StatelessWidget {
  final PassportController passport;
  final CommunityChallengeController communityChallenge;
  final String explorerName;
  final bool isSignedIn;
  final bool showFeaturedAchievements;
  final SettlementProfileController settlement;
  final VoidCallback? onOpenScanner;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenJourney;

  const PassportScreen({
    super.key,
    required this.passport,
    required this.communityChallenge,
    this.explorerName = 'Explorer',
    this.isSignedIn = false,
    this.showFeaturedAchievements = true,
    required this.settlement,
    this.onOpenScanner,
    this.onOpenProfile,
    this.onOpenJourney,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _passportDark,
      body: ColoredBox(
        color: AppThemeColors.background,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              passport,
              settlement,
              communityChallenge,
            ]),
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 1120;

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
                            _PassportHeader(
                              onShowHelp: () => _showHowItWorks(context),
                              onOpenProfile: onOpenProfile,
                            ),
                            SizedBox(height: desktop ? 24 : 18),
                            if (desktop && showFeaturedAchievements)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: _PassportSummary(
                                      passport: passport,
                                      explorerName: explorerName,
                                      isSignedIn: isSignedIn,
                                      onScan: onOpenScanner,
                                      onOpenJourney: onOpenJourney,
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Expanded(
                                    flex: 6,
                                    child: _FeaturedAchievements(
                                      passport: passport,
                                      onScan: onOpenScanner,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _PassportSummary(
                                passport: passport,
                                explorerName: explorerName,
                                isSignedIn: isSignedIn,
                                onScan: onOpenScanner,
                                onOpenJourney: onOpenJourney,
                              ),
                              if (showFeaturedAchievements) ...[
                                SizedBox(height: 16),
                                _FeaturedAchievements(
                                  passport: passport,
                                  onScan: onOpenScanner,
                                ),
                              ],
                            ],
                            SizedBox(height: desktop ? 24 : 16),
                            _CommunityChallengePanel(
                              controller: communityChallenge,
                            ),
                            SizedBox(height: desktop ? 24 : 16),
                            if (desktop)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _BadgeCollection(passport: passport),
                                  ),
                                  const SizedBox(width: 20),
                                  SizedBox(
                                    width: 390,
                                    child: _LocalEssentialsDrawer(
                                      settlement: settlement,
                                      onOpenJourney: onOpenJourney,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _BadgeCollection(passport: passport),
                              const SizedBox(height: 16),
                              _LocalEssentialsDrawer(
                                settlement: settlement,
                                onOpenJourney: onOpenJourney,
                              ),
                            ],
                            SizedBox(height: 20),
                            _RecentDiscoveries(
                              scans: passport.scanHistory,
                              settlement: settlement,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showHowItWorks(BuildContext context) {
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
              constraints: BoxConstraints(maxWidth: 620),
              margin: EdgeInsets.all(14),
              padding: EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _passportDark,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _passportAccent.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _PassportIconBox(
                        icon: Icons.auto_stories_rounded,
                        colour: _passportGreen,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'How your passport works',
                          style: TextStyle(
                            color: _passportText,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: AppLocalizations.of(
                          sheetContext,
                        ).literal('Close'),
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close_rounded, color: _passportMuted),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  _HowItWorksStep(
                    number: '1',
                    title: 'Find a passport QR code',
                    message:
                        'Look for Explore Canada Bay signs at participating places and trails.',
                  ),
                  _HowItWorksStep(
                    number: '2',
                    title: 'Scan once at each discovery',
                    message:
                        'Every code has a unique reward ID, so the same reward cannot be claimed twice.',
                  ),
                  _HowItWorksStep(
                    number: '3',
                    title: 'Grow your collection',
                    message:
                        'A scan can award XP, add progress to a badge, or unlock a special badge immediately.',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CommunityChallengePanel extends StatelessWidget {
  const _CommunityChallengePanel({required this.controller});

  final CommunityChallengeController controller;

  @override
  Widget build(BuildContext context) {
    final challenge = controller.snapshot;
    final strings = AppLocalizations.of(context);
    return _PassportPanel(
      icon: Icons.groups_2_rounded,
      title: 'Community challenge',
      subtitle: 'Your contribution to what Canada Bay achieves together',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _passportGreen.withValues(alpha: 0.18),
                  _passportBlue.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _passportGreen.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.literal(challenge.title),
                        style: TextStyle(
                          color: _passportText,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (controller.loading)
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        onPressed: controller.refresh,
                        tooltip: strings.literal('Refresh community progress'),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  strings.literal(challenge.description),
                  style: TextStyle(
                    color: _passportMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${challenge.communityPoints} / ${challenge.targetPoints} ${strings.literal('community points')}',
                        style: TextStyle(
                          color: _passportText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${(challenge.progress * 100).round()}%',
                      style: TextStyle(
                        color: _passportGreen,
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
                    minHeight: 11,
                    backgroundColor: _passportCardLight,
                    valueColor: AlwaysStoppedAnimation(_passportGreen),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ChallengeMetric(
                      icon: Icons.person_rounded,
                      value: '${challenge.personalPoints}',
                      label: 'your points',
                    ),
                    _ChallengeMetric(
                      icon: Icons.people_alt_rounded,
                      value: '${challenge.contributorCount}',
                      label: 'contributors',
                    ),
                    _ChallengeMetric(
                      icon: Icons.flag_rounded,
                      value: '${challenge.pointsRemaining}',
                      label: 'points to go',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _passportDark.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        challenge.completed
                            ? Icons.celebration_rounded
                            : Icons.redeem_rounded,
                        color: _passportGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.literal(challenge.reward),
                          style: TextStyle(
                            color: _passportText,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!controller.cloudAvailable)
            _ChallengeNotice(
              icon: Icons.cloud_off_rounded,
              message:
                  'Shared progress activates when this build is connected to Supabase.',
            )
          else if (!controller.isSignedIn)
            _ChallengeNotice(
              icon: Icons.login_rounded,
              message:
                  'Sign in from Profile to contribute your Passport activities to the community total.',
            )
          else ...[
            SwitchListTile.adaptive(
              value: challenge.leaderboardOptIn,
              onChanged: controller.loading
                  ? null
                  : controller.setLeaderboardOptIn,
              contentPadding: EdgeInsets.zero,
              activeTrackColor: _passportGreen,
              title: const Text(
                'Join the seasonal leaderboard',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Optional. Only a generated Neighbour alias and your points are shown.',
              ),
            ),
            if (challenge.leaders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Season leaders',
                style: TextStyle(
                  color: _passportText,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              ...challenge.leaders.map(
                (leader) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '#${leader.position}',
                          style: TextStyle(
                            color: _passportGreen,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          leader.alias,
                          style: TextStyle(
                            color: _passportText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${leader.points} pts',
                        style: TextStyle(color: _passportMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          if (controller.error != null) ...[
            const SizedBox(height: 8),
            const _ChallengeNotice(
              icon: Icons.sync_problem_rounded,
              message:
                  'Community progress could not sync. Your Passport activity is safe and will retry.',
            ),
          ],
        ],
      ),
    );
  }
}

class _ChallengeMetric extends StatelessWidget {
  const _ChallengeMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _passportCardLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _passportGreen, size: 17),
          const SizedBox(width: 7),
          Text(
            '$value ${AppLocalizations.of(context).literal(label)}',
            style: TextStyle(
              color: _passportText,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeNotice extends StatelessWidget {
  const _ChallengeNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _passportMuted),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: _passportMuted, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

class _LocalWallet extends StatelessWidget {
  const _LocalWallet({
    required this.settlement,
    this.onOpenJourney,
    this.showHeader = true,
  });

  final SettlementProfileController settlement;
  final VoidCallback? onOpenJourney;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final journeyStrings = JourneyLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My local essentials',
                      style: TextStyle(
                        color: _passportText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Useful details kept with your Community Passport',
                      style: TextStyle(
                        color: AppThemeColors.subtleText,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onOpenJourney, child: const Text('Manage')),
            ],
          ),
          const SizedBox(height: 10),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 580;
            final cards = [
              _EssentialCard(
                icon: Icons.local_library_rounded,
                label: 'Library card',
                value: settlement.libraryCardLabel ?? 'Not added yet',
                detail: settlement.hasLibraryCard
                    ? 'Card reference saved on this device'
                    : 'Join and keep a card reference here',
                onTap: onOpenJourney,
              ),
              _EssentialCard(
                icon: Icons.delete_outline_rounded,
                label: 'Bin collection',
                value: settlement.hasBinDay
                    ? strings.weekday(settlement.binCollectionWeekday!)
                    : 'Not confirmed yet',
                detail: settlement.binReminderEnabled
                    ? 'Reminder on the evening before'
                    : 'Reminder is off',
                onTap: onOpenJourney,
              ),
              _EssentialCard(
                icon: Icons.directions_transit_rounded,
                label: 'Usual stop',
                value: settlement.transportStop ?? 'Not added yet',
                detail: settlement.hasTransportShortcut
                    ? strings.transportMode(
                        settlement.transportMode ?? 'Public transport',
                      )
                    : 'Save a familiar starting point',
                onTap: onOpenJourney,
              ),
              _EssentialCard(
                icon: Icons.report_outlined,
                label: 'Council report',
                value: settlement.councilReportReference ?? 'No report saved',
                detail:
                    settlement.hasCouncilReport &&
                        SettlementProfileController.isDefaultCouncilIssueType(
                          settlement.councilReportType,
                        )
                    ? journeyStrings.ui('councilIssue')
                    : settlement.councilReportType ?? 'Keep a reference handy',
                onTap: onOpenJourney,
              ),
              _EssentialCard(
                icon: Icons.pets_rounded,
                label: 'Pet guide',
                value: settlement.petName ?? 'No pet added',
                detail: settlement.hasPetProfile
                    ? 'Local off-leash guidance ready'
                    : 'Explore pet-friendly local places',
                onTap: onOpenJourney,
              ),
            ];
            const gap = 10.0;
            final width = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LocalEssentialsDrawer extends StatelessWidget {
  const _LocalEssentialsDrawer({required this.settlement, this.onOpenJourney});

  final SettlementProfileController settlement;
  final VoidCallback? onOpenJourney;

  @override
  Widget build(BuildContext context) {
    final completed = [
      settlement.hasLibraryCard,
      settlement.hasBinDay,
      settlement.hasTransportShortcut,
      settlement.councilReportReference != null,
      settlement.hasPetProfile,
    ].where((value) => value).length;

    return Material(
      color: AppThemeColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppThemeColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: CircleAvatar(
            backgroundColor: _passportGreen.withValues(alpha: 0.12),
            child: Icon(Icons.wallet_rounded, color: _passportGreen, size: 20),
          ),
          title: Text(
            'My local wallet',
            style: TextStyle(color: _passportText, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '$completed of 5 essentials saved',
            style: TextStyle(color: _passportMuted, fontSize: 10.5),
          ),
          trailing: const Icon(Icons.expand_more_rounded),
          children: [
            _LocalWallet(
              settlement: settlement,
              onOpenJourney: onOpenJourney,
              showHeader: false,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenJourney,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Manage essentials'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EssentialCard extends StatelessWidget {
  const _EssentialCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _passportCardLight,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _passportGreen.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: _passportGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: _passportMuted,
                        fontSize: 8.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _passportText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppThemeColors.subtleText,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _passportMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassportHeader extends StatelessWidget {
  final VoidCallback onShowHelp;
  final VoidCallback? onOpenProfile;

  const _PassportHeader({required this.onShowHelp, this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(
                color: AppThemeColors.shadow,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              _logoAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.sailing_rounded, color: _passportBlue),
            ),
          ),
        ),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).text('passportTitle'),
                style: TextStyle(
                  color: _passportText,
                  fontSize: 24,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'DISCOVER · SCAN · COLLECT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _passportMuted,
                  fontSize: 9.5,
                  letterSpacing: 1.55,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (onOpenProfile != null) ...[
          IconButton.filledTonal(
            tooltip: AppLocalizations.of(
              context,
            ).literal('Profile and preferences'),
            onPressed: onOpenProfile,
            icon: Icon(Icons.account_circle_outlined),
          ),
          SizedBox(width: 7),
        ],
        IconButton.filledTonal(
          tooltip: AppLocalizations.of(context).literal('How it works'),
          onPressed: onShowHelp,
          icon: Icon(Icons.help_outline_rounded),
        ),
      ],
    );
  }
}

class _PassportSummary extends StatelessWidget {
  const _PassportSummary({
    required this.passport,
    required this.explorerName,
    required this.isSignedIn,
    this.onScan,
    this.onOpenJourney,
  });

  final PassportController passport;
  final String explorerName;
  final bool isSignedIn;
  final VoidCallback? onScan;
  final VoidCallback? onOpenJourney;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _passportBlue,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 21,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_rounded, color: _passportBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        explorerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        isSignedIn ? 'LOCAL EXPLORER' : 'GUEST PASSPORT',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${passport.totalXp} XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              passport.totalScans == 0
                  ? 'Your Canada Bay story starts with one local discovery.'
                  : 'Every place you explore adds another page to your story.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Level ${passport.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${passport.xpToNextLevel} XP to next level',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: passport.levelProgress,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation(_passportGreen),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SummaryStat(
                  value: '${passport.earnedBadgeCount}',
                  label: 'badges',
                ),
                const _SummaryDivider(),
                _SummaryStat(value: '${passport.totalScans}', label: 'scans'),
                const _SummaryDivider(),
                _SummaryStat(value: '+${passport.todayXp}', label: 'today'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onScan,
                    style: FilledButton.styleFrom(
                      backgroundColor: _passportGreen,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Scan'),
                  ),
                ),
                if (onOpenJourney != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenJourney,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      icon: const Icon(Icons.route_rounded, size: 18),
                      label: const Text('Journey'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}

// Legacy layout retained while persisted passport profiles migrate to summary UI.
// ignore: unused_element
class _PassportIdentityCard extends StatelessWidget {
  final PassportController passport;
  final String explorerName;
  final bool isSignedIn;
  final VoidCallback? onScan;
  final VoidCallback? onOpenJourney;

  const _PassportIdentityCard({
    required this.passport,
    required this.explorerName,
    required this.isSignedIn,
    // ignore: unused_element_parameter
    this.onScan,
    // ignore: unused_element_parameter
    this.onOpenJourney,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _passportBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _passportOnBrandMuted.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppThemeColors.shadow,
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _passportGreen,
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$explorerName's Passport",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'CANADA BAY EXPLORER',
                      style: TextStyle(
                        color: _passportOnBrandMuted,
                        fontSize: 9,
                        letterSpacing: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSignedIn
                          ? Icons.person_pin_circle_rounded
                          : Icons.phone_iphone_rounded,
                      color: _passportGreen,
                      size: 15,
                    ),
                    SizedBox(width: 6),
                    Text(
                      isSignedIn ? 'LOCAL PROFILE' : 'GUEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: passport.levelProgress,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withValues(alpha: 0.09),
                    valueColor: AlwaysStoppedAnimation(_passportGreen),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${passport.totalXp}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'EXPLORATION POINTS',
                        style: TextStyle(
                          color: _passportOnBrandMuted,
                          fontSize: 9.5,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
          Center(
            child: Text(
              'Journey level ${passport.level} · ${passport.xpToNextLevel} points to the next milestone',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 18),
          Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PassportMetric(
                    value: '${passport.earnedBadgeCount}',
                    label: 'Stamps',
                    icon: Icons.workspace_premium_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                Expanded(
                  child: _PassportMetric(
                    value: '${passport.totalScans}',
                    label: 'Scans',
                    icon: Icons.qr_code_scanner_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                Expanded(
                  child: _PassportMetric(
                    value: '+${passport.todayXp}',
                    label: 'Today',
                    icon: Icons.bolt_rounded,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          Material(
            color: Colors.white.withValues(alpha: 0.08),
            child: InkWell(
              onTap: onOpenJourney,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(Icons.route_rounded, color: Color(0xFF8FF5D1)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Continue your newcomer journey',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onScan,
              style: FilledButton.styleFrom(
                backgroundColor: _passportGreen,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(Icons.qr_code_scanner_rounded),
              label: Text(
                passport.totalScans == 0
                    ? 'Make your first discovery'
                    : 'Scan another discovery',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassportMetric extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _PassportMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: _passportGreen, size: 19),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _passportOnBrandMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FeaturedAchievements extends StatelessWidget {
  final PassportController passport;
  final VoidCallback? onScan;

  const _FeaturedAchievements({required this.passport, this.onScan});

  @override
  Widget build(BuildContext context) {
    final featured = passport.featuredBadges;

    return _PassportPanel(
      icon: Icons.auto_awesome_rounded,
      title: 'Your passport shelf',
      subtitle: featured.isEmpty
          ? 'Collect a first stamp and begin your story'
          : 'The achievements you are proud to display',
      child: featured.isEmpty
          ? _FirstDiscoveryInvitation(onScan: onScan)
          : Row(
              children: List.generate(3, (index) {
                final badge = index < featured.length ? featured[index] : null;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 2 ? 0 : 9),
                    child: Container(
                      height: 112,
                      decoration: BoxDecoration(
                        color: badge == null
                            ? AppThemeColors.background.withValues(alpha: 0.28)
                            : Color(badge.colourValue).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: badge == null
                              ? AppThemeColors.border
                              : Color(badge.colourValue).withValues(alpha: 0.4),
                        ),
                      ),
                      child: badge == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  color: _passportMuted,
                                  size: 23,
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Empty',
                                  style: TextStyle(
                                    color: _passportMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _BadgeArtwork(badge: badge, size: 31),
                                SizedBox(height: 7),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 5),
                                  child: Text(
                                    badge.localizedName(
                                      Localizations.localeOf(
                                        context,
                                      ).languageCode,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _passportText,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              }),
            ),
    );
  }
}

class _FirstDiscoveryInvitation extends StatelessWidget {
  const _FirstDiscoveryInvitation({this.onScan});

  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _passportGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _passportGreen.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: _passportGreen.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: _passportGreen,
              size: 31,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A blank page, ready for you',
                  style: TextStyle(
                    color: _passportText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Visit a participating place and scan its passport sign.',
                  style: TextStyle(
                    color: AppThemeColors.subtleText,
                    height: 1.35,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 9),
                TextButton.icon(
                  onPressed: onScan,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                  label: const Text('Find my first stamp'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCollection extends StatelessWidget {
  final PassportController passport;

  const _BadgeCollection({required this.passport});

  @override
  Widget build(BuildContext context) {
    final badges = passport.badges;
    final earned = badges.where((badge) => badge.earned).length;
    final collections = <String, List<PassportBadge>>{};
    for (final badge in badges) {
      collections.putIfAbsent(badge.collection, () => []).add(badge);
    }

    return _PassportPanel(
      icon: Icons.emoji_events_rounded,
      title: 'Community collections',
      subtitle:
          '${collections.length} collections · $earned of ${badges.length} stamps earned',
      child: Column(
        children: collections.entries
            .map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == collections.keys.last ? 0 : 16,
                ),
                child: _CollapsibleTrophyCase(
                  name: entry.value.first.localizedCollection(
                    Localizations.localeOf(context).languageCode,
                  ),
                  badges: entry.value,
                  passport: passport,
                  initiallyExpanded: entry.key == collections.keys.first,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CollapsibleTrophyCase extends StatelessWidget {
  const _CollapsibleTrophyCase({
    required this.name,
    required this.badges,
    required this.passport,
    this.initiallyExpanded = false,
  });

  final String name;
  final List<PassportBadge> badges;
  final PassportController passport;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final earned = badges.where((badge) => badge.earned).length;
    return Material(
      color: AppThemeColors.surfaceAlt,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppThemeColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: _passportGreen.withValues(alpha: 0.12),
            child: Icon(
              Icons.emoji_events_rounded,
              color: _passportGreen,
              size: 19,
            ),
          ),
          title: Text(
            name,
            style: TextStyle(color: _passportText, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '$earned of ${badges.length} earned',
            style: TextStyle(color: _passportMuted, fontSize: 10.5),
          ),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600 ? 2 : 1;
                const gap = 10.0;
                final width =
                    (constraints.maxWidth - ((columns - 1) * gap)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: badges.map((badge) {
                    final featured = passport.featuredBadgeIds.contains(
                      badge.id,
                    );
                    return SizedBox(
                      width: width,
                      child: _BadgeCard(
                        badge: badge,
                        featured: featured,
                        onToggleFeatured: badge.earned
                            ? () => _toggleFeatured(context, badge, featured)
                            : null,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFeatured(
    BuildContext context,
    PassportBadge badge,
    bool featured,
  ) {
    if (!featured && passport.featuredBadgeIds.length >= 3) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Remove one displayed trophy before adding another.'),
          ),
        );
      return;
    }
    passport.toggleFeaturedBadge(badge.id);
  }
}

// Legacy expanded case retained for desktop comparison during migration.
// ignore: unused_element
class _TrophyCase extends StatelessWidget {
  final String name;
  final List<PassportBadge> badges;
  final PassportController passport;

  const _TrophyCase({
    required this.name,
    required this.badges,
    required this.passport,
  });

  @override
  Widget build(BuildContext context) {
    final earned = badges.where((badge) => badge.earned).length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeColors.background.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _passportGreen.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: _passportGreen,
                  size: 18,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: _passportText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$earned/${badges.length}',
                style: TextStyle(
                  color: _passportMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 2 : 1;
              const gap = 10.0;
              final width =
                  (constraints.maxWidth - ((columns - 1) * gap)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: badges.map((badge) {
                  final isFeatured = passport.featuredBadgeIds.contains(
                    badge.id,
                  );
                  return SizedBox(
                    width: width,
                    child: _BadgeCard(
                      badge: badge,
                      featured: isFeatured,
                      onToggleFeatured: badge.earned
                          ? () {
                              if (!isFeatured &&
                                  passport.featuredBadgeIds.length >= 3) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Choose one displayed trophy to remove before adding another.',
                                      ),
                                    ),
                                  );
                                return;
                              }
                              passport.toggleFeaturedBadge(badge.id);
                            }
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final PassportBadge badge;
  final bool featured;
  final VoidCallback? onToggleFeatured;

  const _BadgeCard({
    required this.badge,
    required this.featured,
    this.onToggleFeatured,
  });

  @override
  Widget build(BuildContext context) {
    final colour = Color(badge.colourValue);
    final progress = (badge.progress / badge.target).clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: Duration(milliseconds: 320),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: badge.earned
            ? colour.withValues(alpha: AppThemeColors.isDark ? 0.18 : 0.07)
            : AppThemeColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badge.earned
              ? colour.withValues(alpha: 0.55)
              : _passportAccent.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colour.withValues(alpha: 0.48),
                    width: 2,
                  ),
                ),
                child: _BadgeArtwork(
                  badge: badge,
                  size: 27,
                  muted: !badge.earned,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.localizedName(
                        Localizations.localeOf(context).languageCode,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _passportText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      badge.earned
                          ? 'Badge earned'
                          : '${badge.progress}/${badge.target} discoveries',
                      style: TextStyle(
                        color: badge.earned ? colour : _passportMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).literal(
                  badge.earned
                      ? featured
                            ? 'Remove from display'
                            : 'Display this trophy'
                      : 'Earn this trophy to display it',
                ),
                onPressed: onToggleFeatured,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  badge.earned
                      ? featured
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded
                      : Icons.lock_outline_rounded,
                  color: badge.earned ? colour : _passportMuted,
                  size: 20,
                ),
              ),
            ],
          ),
          SizedBox(height: 13),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              badge
                  .localizedRarity(Localizations.localeOf(context).languageCode)
                  .toUpperCase(),
              style: TextStyle(
                color: colour,
                fontSize: 8,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: 10),
          Text(
            badge.localizedDescription(
              Localizations.localeOf(context).languageCode,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _passportMuted,
              fontSize: 10.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              color: colour,
              backgroundColor: AppThemeColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentDiscoveries extends StatelessWidget {
  final List<PassportScanRecord> scans;
  final SettlementProfileController settlement;

  const _RecentDiscoveries({required this.scans, required this.settlement});

  @override
  Widget build(BuildContext context) {
    return _PassportPanel(
      icon: Icons.history_rounded,
      title: 'Recent Discoveries',
      subtitle: 'Your latest passport rewards',
      child: scans.isEmpty
          ? Container(
              width: double.infinity,
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _passportCardLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  _PassportIconBox(
                    icon: Icons.qr_code_scanner_rounded,
                    colour: _passportGreen,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your first discovery is waiting. Scan a Canada Bay passport QR code to begin.',
                      style: TextStyle(
                        color: _passportMuted,
                        height: 1.45,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: scans.take(6).map((scan) {
                final localized = JourneyActivityLocalizations.of(
                  context,
                ).resolve(scan, settlement: settlement);
                return Container(
                  margin: EdgeInsets.only(bottom: 9),
                  padding: EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _passportCardLight,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    children: [
                      _PassportIconBox(
                        icon: Icons.place_rounded,
                        colour: _passportGreen,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localized.placeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _passportText,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              _formatScanDate(context, scan.scannedAt),
                              style: TextStyle(
                                color: _passportMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (scan.content != null)
                        IconButton(
                          tooltip: AppLocalizations.of(
                            context,
                          ).literal('Read unlocked information'),
                          onPressed: () =>
                              _showDiscoveryDetails(context, localized),
                          icon: Icon(
                            Icons.menu_book_rounded,
                            color: _passportAccent,
                          ),
                        ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _passportGreen.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          scan.xpAwarded > 0
                              ? '+${scan.xpAwarded} XP'
                              : scan.content != null
                              ? 'STORY'
                              : 'STAMP',
                          style: TextStyle(
                            color: _passportGreen,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  String _formatScanDate(BuildContext context, DateTime value) {
    final now = DateTime.now();
    final local = value.toLocal();
    if (now.difference(local).inDays == 0 && now.day == local.day) {
      final time = MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
      return AppLocalizations.of(context).literal('Today at $time');
    }
    return MaterialLocalizations.of(context).formatCompactDate(local);
  }

  void _showDiscoveryDetails(
    BuildContext context,
    LocalizedJourneyActivity activity,
  ) {
    final content = activity.content;
    if (content == null) return;

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DiscoveryDetailsSheet(
        placeName: activity.placeName,
        content: content,
      ),
    );
  }
}

class _DiscoveryDetailsSheet extends StatelessWidget {
  const _DiscoveryDetailsSheet({
    required this.placeName,
    required this.content,
  });

  final String placeName;
  final PassportQrContent content;

  Future<void> _openSource(BuildContext context) async {
    final url = content.officialUrl;
    if (url == null) return;

    final opened = await const ExternalLinkService().open(url);
    if (opened || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('The link could not open, so it was copied instead.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        margin: EdgeInsets.all(12),
        padding: EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _passportDark,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _passportAccent.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: AppThemeColors.shadow,
              blurRadius: 32,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PassportIconBox(
                    icon: Icons.menu_book_rounded,
                    colour: _passportGreen,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.category.toUpperCase(),
                          style: TextStyle(
                            color: _passportGreen,
                            fontSize: 9,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          placeName,
                          style: TextStyle(
                            color: _passportMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: AppLocalizations.of(context).literal('Close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded),
                  ),
                ],
              ),
              SizedBox(height: 18),
              Text(
                content.title,
                style: TextStyle(
                  color: _passportText,
                  fontSize: 24,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12),
              Text(
                content.body,
                style: TextStyle(
                  color: _passportMuted,
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (content.officialUrl != null) ...[
                SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openSource(context),
                    icon: Icon(Icons.open_in_new_rounded),
                    label: Text('Open official source'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _passportGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: StadiumBorder(),
                    ),
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

class _PassportPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _PassportPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
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
              _PassportIconBox(icon: icon, colour: _passportMuted),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _passportText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _passportMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 17),
          child,
        ],
      ),
    );
  }
}

class _PassportIconBox extends StatelessWidget {
  final IconData icon;
  final Color colour;

  const _PassportIconBox({required this.icon, required this.colour});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: colour, size: 21),
    );
  }
}

class _BadgeArtwork extends StatelessWidget {
  const _BadgeArtwork({
    required this.badge,
    required this.size,
    this.muted = false,
  });

  final PassportBadge badge;
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colour = Color(badge.colourValue);
    final fallback = Icon(
      _badgeIcon(badge.iconName),
      color: muted ? colour.withValues(alpha: 0.7) : colour,
      size: size,
    );
    final asset = (badge.imageAsset ?? '').trim();
    if (asset.isEmpty) return fallback;

    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: AppLocalizations.of(context).literal(
        '${badge.localizedName(Localizations.localeOf(context).languageCode)} badge artwork',
      ),
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final String title;
  final String message;

  const _HowItWorksStep({
    required this.number,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _passportGreen.withValues(alpha: 0.17),
            child: Text(
              number,
              style: TextStyle(
                color: _passportGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _passportText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: _passportMuted,
                    fontSize: 11.5,
                    height: 1.45,
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

IconData _badgeIcon(String name) {
  switch (name) {
    case 'eco':
    case 'eco_rounded':
      return Icons.eco_rounded;
    case 'restaurant':
    case 'restaurant_rounded':
      return Icons.restaurant_rounded;
    case 'museum':
    case 'museum_rounded':
    case 'account_balance_rounded':
      return Icons.museum_rounded;
    case 'waves':
    case 'waves_rounded':
      return Icons.waves_rounded;
    case 'park':
    case 'park_rounded':
      return Icons.park_rounded;
    case 'fitness':
    case 'fitness_center_rounded':
      return Icons.fitness_center_rounded;
    case 'local_library_rounded':
      return Icons.local_library_rounded;
    case 'groups_rounded':
      return Icons.groups_rounded;
    case 'volunteer_activism_rounded':
      return Icons.volunteer_activism_rounded;
    case 'storefront_rounded':
      return Icons.storefront_rounded;
    case 'palette_rounded':
      return Icons.palette_rounded;
    default:
      return Icons.workspace_premium_rounded;
  }
}
