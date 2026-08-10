import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/community_services_localizations.dart';
import '../models/local_service_item.dart';
import '../services/external_link_service.dart';
import '../services/local_services_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/localized_text.dart';

const _emergencyRed = Color(0xFFD94747);
const _emergencyDark = Color(0xFF6F2026);

/// A trusted, searchable starting point for practical local information.
class LocalServicesScreen extends StatefulWidget {
  const LocalServicesScreen({
    super.key,
    this.repository = const LocalServicesRepository(),
    this.onOpenJourney,
  });

  final LocalServicesRepository repository;
  final VoidCallback? onOpenJourney;

  @override
  State<LocalServicesScreen> createState() => _LocalServicesScreenState();
}

class _LocalServicesScreenState extends State<LocalServicesScreen> {
  final _searchController = TextEditingController();
  late Future<LocalServicesCatalog> _catalogFuture;
  LocalServiceCategory? _selectedCategory;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _catalogFuture = widget.repository.loadCatalog();
  }

  @override
  void didUpdateWidget(covariant LocalServicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _catalogFuture = widget.repository.loadCatalog();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _catalogFuture = widget.repository.loadCatalog();
    });
  }

  void _showService(LocalServiceItem service) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (context) => _ServiceDetailsSheet(service: service),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: ColoredBox(
        color: AppThemeColors.background,
        child: SafeArea(
          bottom: false,
          child: FutureBuilder<LocalServicesCatalog>(
            future: _catalogFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _LoadingView();
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return _ErrorView(onRetry: _retry);
              }

              return _buildDirectory(context, snapshot.requireData);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDirectory(BuildContext context, LocalServicesCatalog catalog) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final copy = CommunityServicesLocalizations.of(context);
    final emergency = catalog.services
        .singleWhere((service) => service.isEmergency)
        .localized(languageCode);
    final categories = LocalServiceCategory.values
        .where(
          (category) =>
              category != LocalServiceCategory.emergency &&
              catalog.services.any((item) => item.category == category),
        )
        .toList();
    final filteredServices = catalog.services
        .where((service) {
          if (service.isEmergency) return false;
          final categoryMatches =
              _selectedCategory == null ||
              service.category == _selectedCategory;
          return categoryMatches &&
              service.matches(_query, languageCode: languageCode);
        })
        .map((service) => service.localized(languageCode))
        .toList();
    final essentialServices = catalog.services
        .where((service) => service.isEssential && !service.isEmergency)
        .take(4)
        .map((service) => service.localized(languageCode))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;
        final horizontalPadding = mobile ? 16.0 : 32.0;
        return Scrollbar(
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  mobile ? 14 : 24,
                  horizontalPadding,
                  48,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DirectoryHeader(lastReviewed: catalog.lastReviewed),
                          SizedBox(height: mobile ? 14 : 22),
                          if (!mobile) ...[
                            _JourneyInvitation(onTap: widget.onOpenJourney),
                            const SizedBox(height: 28),
                          ],
                          _EmergencyPanel(
                            service: emergency,
                            onTap: () => _showService(emergency),
                          ),
                          SizedBox(height: mobile ? 18 : 32),
                          _SectionHeading(
                            eyebrow: copy.text('services.startHere'),
                            title: copy.text('services.everydayEssentials'),
                            description: copy.text(
                              'services.essentialDescription',
                            ),
                          ),
                          SizedBox(height: mobile ? 10 : 16),
                          if (!mobile) ...[
                            _QuickActions(
                              services: essentialServices,
                              onTap: _showService,
                            ),
                            const SizedBox(height: 36),
                          ],
                          _SearchAndFilters(
                            controller: _searchController,
                            categories: categories,
                            selectedCategory: _selectedCategory,
                            onQueryChanged: (value) {
                              setState(() => _query = value);
                            },
                            onCategoryChanged: (category) {
                              setState(() => _selectedCategory = category);
                            },
                          ),
                          const SizedBox(height: 24),
                          _ResultsHeader(
                            count: filteredServices.length,
                            hasFilters:
                                _query.trim().isNotEmpty ||
                                _selectedCategory != null,
                            onClear: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _selectedCategory = null;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          if (filteredServices.isEmpty)
                            _EmptyResults(
                              onClear: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _selectedCategory = null;
                                });
                              },
                            )
                          else
                            _ServicesGrid(
                              services: filteredServices,
                              onTap: _showService,
                            ),
                          const SizedBox(height: 28),
                          _TrustNotice(lastReviewed: catalog.lastReviewed),
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

class _JourneyInvitation extends StatelessWidget {
  const _JourneyInvitation({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Material(
      color: const Color(0xFF0A5B65),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              const Icon(Icons.route_rounded, color: Color(0xFF8FF5D1)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.text('services.newcomerTitle').toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF8FF5D1),
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.text('services.newcomerBody'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
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
}

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({required this.lastReviewed});

  final DateTime lastReviewed;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final brand = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/images/canada_bay_logo.jpg',
                width: compact ? 58 : 68,
                height: compact ? 58 : 68,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).text('services').toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppThemeColors.accentGreen,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context).text('servicesTagline'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppThemeColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final verified = SizedBox(
          width: compact ? constraints.maxWidth : 360,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppThemeColors.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppThemeColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 19,
                  color: AppThemeColors.accentGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    copy.text('services.reviewed', {
                      'date': MaterialLocalizations.of(
                        context,
                      ).formatMonthYear(lastReviewed),
                    }),
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppThemeColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [brand, const SizedBox(height: 18), verified],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: brand),
            const SizedBox(width: 24),
            verified,
          ],
        );
      },
    );
  }
}

class _EmergencyPanel extends StatelessWidget {
  const _EmergencyPanel({required this.service, required this.onTap});

  final LocalServiceItem service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Semantics(
      label: copy.text('services.emergencySemantics'),
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: _emergencyDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final information = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.emergency_rounded,
                        color: Colors.white,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.text('services.urgentHelp').toUpperCase(),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: const Color(0xFFFFD8D8),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            copy.text('services.knowTripleZero'),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            copy.text('services.emergencyDescription'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final callout = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.call_rounded,
                        color: _emergencyDark,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '000',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: _emergencyDark,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: _emergencyDark,
                        size: 19,
                      ),
                    ],
                  ),
                );

                return Padding(
                  padding: EdgeInsets.all(compact ? 20 : 26),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            information,
                            const SizedBox(height: 18),
                            callout,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: information),
                            const SizedBox(width: 30),
                            callout,
                          ],
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppThemeColors.accentGreen,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppThemeColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppThemeColors.subtleText,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.services, required this.onTap});

  final List<LocalServiceItem> services;
  final ValueChanged<LocalServiceItem> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 570
            ? 2
            : 1;
        const gap = 14.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final service in services)
              SizedBox(
                width: width,
                child: _QuickActionCard(
                  service: service,
                  onTap: () => onTap(service),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.service, required this.onTap});

  final LocalServiceItem service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent(service.category);
    return Material(
      color: AppThemeColors.surface.withValues(alpha: 0.58),
      child: InkWell(
        onTap: onTap,
        child: Ink(
          height: 104,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accent, width: 4),
              top: BorderSide(color: AppThemeColors.border),
              bottom: BorderSide(color: AppThemeColors.border),
            ),
          ),
          child: Row(
            children: [
              Icon(_categoryIcon(service.category), color: accent, size: 29),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  service.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppThemeColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.arrow_outward_rounded, color: AppThemeColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.categories,
    required this.selectedCategory,
    required this.onQueryChanged,
    required this.onCategoryChanged,
  });

  final TextEditingController controller;
  final List<LocalServiceCategory> categories;
  final LocalServiceCategory? selectedCategory;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<LocalServiceCategory?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppThemeColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: AppThemeColors.text),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).text('servicesSearch'),
              hintStyle: TextStyle(color: AppThemeColors.subtleText),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppThemeColors.accentCyan,
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: copy.text('shared.clearSearch'),
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppThemeColors.background.withValues(alpha: 0.48),
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
                borderSide: BorderSide(
                  color: AppThemeColors.accentGreen,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 17),
            ),
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CategoryChip(
                  label: copy.text('services.all'),
                  icon: Icons.grid_view_rounded,
                  selected: selectedCategory == null,
                  onTap: () => onCategoryChanged(null),
                ),
                for (final category in categories) ...[
                  const SizedBox(width: 9),
                  _CategoryChip(
                    label: copy.serviceCategory(category.name),
                    icon: _categoryIcon(category),
                    selected: selectedCategory == category,
                    onTap: () => onCategoryChanged(category),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? AppThemeColors.background : AppThemeColors.muted,
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppThemeColors.accentGreen : AppThemeColors.border,
        ),
      ),
      backgroundColor: AppThemeColors.surfaceAlt,
      selectedColor: AppThemeColors.accentGreen,
      labelStyle: TextStyle(
        color: selected ? AppThemeColors.background : AppThemeColors.text,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.hasFilters,
    required this.onClear,
  });

  final int count;
  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            count == 1
                ? copy.text('services.trustedOne')
                : copy.text('services.trustedMany', {'count': count}),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppThemeColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (hasFilters)
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
            label: Text(copy.text('shared.clearFilters')),
          ),
      ],
    );
  }
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid({required this.services, required this.onTap});

  final List<LocalServiceItem> services;
  final ValueChanged<LocalServiceItem> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final service in services)
              SizedBox(
                width: width,
                child: _ServiceCard(
                  service: service,
                  onTap: () => onTap(service),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTap});

  final LocalServiceItem service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent(service.category);
    final copy = CommunityServicesLocalizations.of(context);
    return Material(
      color: AppThemeColors.surface.withValues(alpha: 0.62),
      child: InkWell(
        onTap: onTap,
        child: Ink(
          height: 238,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppThemeColors.border),
              bottom: BorderSide(color: AppThemeColors.border),
              left: BorderSide(color: accent, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _categoryIcon(service.category),
                    color: accent,
                    size: 27,
                  ),
                  const Spacer(),
                  Text(
                    copy.serviceCategory(service.category.name).toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppThemeColors.muted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                service.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppThemeColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                service.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppThemeColors.subtleText,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: AppThemeColors.accentGreen,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      service.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppThemeColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      copy.text('services.viewDetails'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: accent, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: AppThemeColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 44, color: AppThemeColors.muted),
          const SizedBox(height: 14),
          Text(
            copy.text('services.noMatches'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppThemeColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            copy.text('services.trySearch'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppThemeColors.subtleText),
          ),
          const SizedBox(height: 18),
          FilledButton.tonal(
            onPressed: onClear,
            child: Text(copy.text('services.showAll')),
          ),
        ],
      ),
    );
  }
}

class _TrustNotice extends StatelessWidget {
  const _TrustNotice({required this.lastReviewed});

  final DateTime lastReviewed;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppThemeColors.surfaceAlt.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: AppThemeColors.accentCyan,
            size: 24,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              copy.text('services.trustNotice', {
                'date': MaterialLocalizations.of(
                  context,
                ).formatMonthYear(lastReviewed),
              }),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppThemeColors.subtleText,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceDetailsSheet extends StatelessWidget {
  const _ServiceDetailsSheet({required this.service});

  final LocalServiceItem service;

  Future<void> _open(
    BuildContext context, {
    required String value,
    required String description,
    bool isPhone = false,
  }) async {
    final target = isPhone
        ? 'tel:${value.replaceAll(RegExp(r'[^0-9+]'), '')}'
        : value;
    final opened = await const ExternalLinkService().open(target);
    if (opened || !context.mounted) return;

    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    final copy = CommunityServicesLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            copy.text('services.openFailed', {'description': description}),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final accent = service.isEmergency
        ? _emergencyRed
        : _categoryAccent(service.category);
    final copy = CommunityServicesLocalizations.of(context);
    final availableHeight = MediaQuery.sizeOf(context).height;
    return Container(
      height: math.min(720, availableHeight * 0.9),
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: AppThemeColors.muted.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    _categoryIcon(service.category),
                    color: accent,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    copy.serviceCategory(service.category.name),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: copy.text('shared.close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppThemeColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    service.summary,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppThemeColors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    service.details,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppThemeColors.subtleText,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 26),
                  for (final highlight in service.highlights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 25,
                            height: 25,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: accent,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              highlight,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppThemeColors.text,
                                    height: 1.5,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 17),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppThemeColors.background.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppThemeColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: AppThemeColors.accentGreen,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                copy.text('services.officialSourceWithName', {
                                  'source': service.sourceLabel,
                                }),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppThemeColors.text,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          service.officialUrl,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppThemeColors.accentCyan,
                                height: 1.45,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final buttons = <Widget>[
                        FilledButton.icon(
                          onPressed: () => _open(
                            context,
                            value: service.officialUrl,
                            description: copy.text('services.officialLink'),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(service.actionLabel),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                        if (service.phone != null)
                          OutlinedButton.icon(
                            onPressed: () => _open(
                              context,
                              value: service.phone!,
                              description: copy.text('services.phoneNumber'),
                              isPhone: true,
                            ),
                            icon: const Icon(Icons.call_rounded),
                            label: Text(
                              copy.text('services.call', {
                                'phone': service.phone!,
                              }),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              side: BorderSide(color: accent),
                              foregroundColor: accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                          ),
                      ];

                      if (constraints.maxWidth < 520 || buttons.length == 1) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var index = 0; index < buttons.length; index++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == buttons.length - 1 ? 0 : 10,
                                ),
                                child: buttons[index],
                              ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          for (
                            var index = 0;
                            index < buttons.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(width: 10),
                            Expanded(child: buttons[index]),
                          ],
                        ],
                      );
                    },
                  ),
                  if (service.isEmergency) ...[
                    const SizedBox(height: 18),
                    Text(
                      copy.text('services.emergencyDisclaimer'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _emergencyRed,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppThemeColors.accentGreen),
          const SizedBox(height: 18),
          Text(
            copy.text('services.loading'),
            style: TextStyle(color: AppThemeColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppThemeColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppThemeColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: AppThemeColors.muted,
              ),
              const SizedBox(height: 16),
              Text(
                copy.text('services.unavailable'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppThemeColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.text('services.loadError'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppThemeColors.subtleText, height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(copy.text('shared.tryAgain')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _categoryIcon(LocalServiceCategory category) => switch (category) {
  LocalServiceCategory.waste => Icons.recycling_rounded,
  LocalServiceCategory.parks => Icons.outdoor_grill_rounded,
  LocalServiceCategory.libraries => Icons.local_library_rounded,
  LocalServiceCategory.transport => Icons.directions_transit_rounded,
  LocalServiceCategory.parking => Icons.local_parking_rounded,
  LocalServiceCategory.amenities => Icons.wc_rounded,
  LocalServiceCategory.emergency => Icons.emergency_rounded,
  LocalServiceCategory.council => Icons.campaign_rounded,
  LocalServiceCategory.pets => Icons.pets_rounded,
};

Color _categoryAccent(LocalServiceCategory category) => switch (category) {
  LocalServiceCategory.waste => const Color(0xFF25B58A),
  LocalServiceCategory.parks => const Color(0xFF62B85C),
  LocalServiceCategory.libraries => const Color(0xFF8C71E8),
  LocalServiceCategory.transport => const Color(0xFF39A4D8),
  LocalServiceCategory.parking => const Color(0xFF478CDD),
  LocalServiceCategory.amenities => const Color(0xFF21A9A8),
  LocalServiceCategory.emergency => _emergencyRed,
  LocalServiceCategory.council => const Color(0xFFF09C45),
  LocalServiceCategory.pets => const Color(0xFFD077A9),
};
