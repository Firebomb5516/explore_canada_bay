import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../l10n/community_services_localizations.dart';
import '../models/community_item.dart';
import '../services/community_repository.dart';
import '../services/external_link_service.dart';
import '../theme/app_theme.dart';
import '../widgets/localized_text.dart';

const _communityLogoAsset = 'assets/images/canada_bay_logo.jpg';
const _communityBlue = Color(0xFF0D4F7C);

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    this.repository = const CommunityRepository(),
    this.onOpenJourney,
  });

  final CommunityRepository repository;
  final VoidCallback? onOpenJourney;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<CommunityItem> _items = const [];
  CommunityCategory? _selectedCategory;
  String _query = '';
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  @override
  void didUpdateWidget(covariant CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _loadCommunity();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunity() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<CommunityItem> _filteredItems(String languageCode) => _items
      .where((item) {
        final categoryMatches =
            _selectedCategory == null || item.category == _selectedCategory;
        return categoryMatches &&
            item.matches(_query, languageCode: languageCode);
      })
      .map((item) => item.localized(languageCode))
      .toList(growable: false);

  List<CommunityCategory> get _availableCategories => CommunityCategory.values
      .where((category) => _items.any((item) => item.category == category))
      .toList(growable: false);

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty || _selectedCategory != null;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedCategory = null;
    });
  }

  void _showDetails(CommunityItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CommunityDetailSheet(
        item: item,
        onOpenLink: () => _openOfficialLink(sheetContext, item),
      ),
    );
  }

  Future<void> _openOfficialLink(
    BuildContext context,
    CommunityItem item,
  ) async {
    final opened = await const ExternalLinkService().open(item.officialUrl);
    if (opened || !context.mounted) return;

    await Clipboard.setData(ClipboardData(text: item.officialUrl));
    if (!context.mounted) return;
    final copy = CommunityServicesLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            copy.text('community.openFailed', {'source': item.sourceLabel}),
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: copy.text('shared.done'),
            onPressed: () {},
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeColors.background,
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _buildState(),
        ),
      ),
    );
  }

  Widget _buildState() {
    if (_loading) {
      return const _CommunityLoading(key: ValueKey('community-loading'));
    }
    if (_error != null) {
      return _CommunityError(
        key: const ValueKey('community-error'),
        onRetry: _loadCommunity,
      );
    }

    final languageCode = Localizations.localeOf(context).languageCode;
    final filtered = _filteredItems(languageCode);
    final featured = _items
        .where((item) => item.featured)
        .take(5)
        .map((item) => item.localized(languageCode))
        .toList();

    return RefreshIndicator(
      key: const ValueKey('community-content'),
      color: AppThemeColors.accentGreen,
      backgroundColor: AppThemeColors.surface,
      onRefresh: _loadCommunity,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  child: _CommunityHeader(itemCount: _items.length),
                ),
              ),
            ),
          ),
          if (widget.onOpenJourney != null)
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: _NewcomerBridge(onTap: widget.onOpenJourney!),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                  child: _DiscoveryControls(
                    controller: _searchController,
                    query: _query,
                    categories: _availableCategories,
                    selectedCategory: _selectedCategory,
                    onQueryChanged: (value) => setState(() => _query = value),
                    onClearQuery: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    onCategorySelected: (category) {
                      setState(() => _selectedCategory = category);
                    },
                  ),
                ),
              ),
            ),
          ),
          if (!_hasActiveFilters && featured.isNotEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: _FeaturedStrip(items: featured, onOpen: _showDetails),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    !_hasActiveFilters && featured.isNotEmpty ? 22 : 26,
                    18,
                    12,
                  ),
                  child: _ResultsHeading(
                    count: filtered.length,
                    category: _selectedCategory,
                    query: _query,
                    hasActiveFilters: _hasActiveFilters,
                    onClear: _clearFilters,
                  ),
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyResults(onClear: _clearFilters),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.crossAxisExtent >= 900 ? 2 : 1;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 22,
                      mainAxisExtent: 146,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 579),
                          child: _CommunityListItem(
                            item: filtered[index],
                            onTap: () => _showDetails(filtered[index]),
                          ),
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: _OfficialSourceFooter()),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }
}

class _NewcomerBridge extends StatelessWidget {
  const _NewcomerBridge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Material(
      color: AppThemeColors.accentGreen.withValues(
        alpha: AppThemeColors.isDark ? 0.14 : 0.08,
      ),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Icon(
                Icons.waving_hand_rounded,
                color: AppThemeColors.accentGreen,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.text('community.newcomerTitle'),
                      style: TextStyle(
                        color: AppThemeColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      copy.text('community.newcomerBody'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppThemeColors.subtleText,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppThemeColors.accentGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final copy = CommunityServicesLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(
                color: AppThemeColors.shadow,
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              _communityLogoAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.sailing_rounded, color: _communityBlue),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.text('community'),
                style: TextStyle(
                  color: AppThemeColors.text,
                  fontSize: 24,
                  height: 1,
                  letterSpacing: -0.7,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                copy.text('community.subtitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppThemeColors.subtleText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppThemeColors.accentGreen.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_rounded,
                size: 15,
                color: AppThemeColors.accentGreen,
              ),
              const SizedBox(width: 5),
              Text(
                copy.text('community.trustedLeads', {'count': itemCount}),
                style: TextStyle(
                  color: AppThemeColors.accentGreen,
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
}

class _DiscoveryControls extends StatelessWidget {
  const _DiscoveryControls({
    required this.controller,
    required this.query,
    required this.categories,
    required this.selectedCategory,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onCategorySelected,
  });

  final TextEditingController controller;
  final String query;
  final List<CommunityCategory> categories;
  final CommunityCategory? selectedCategory;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<CommunityCategory?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final copy = CommunityServicesLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('community-search'),
          controller: controller,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(
            color: AppThemeColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: strings.text('searchCommunity'),
            hintStyle: TextStyle(
              color: AppThemeColors.subtleText,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: AppThemeColors.muted),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: copy.text('shared.clearSearch'),
                    onPressed: onClearQuery,
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: AppThemeColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: AppThemeColors.accentGreen,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            children: [
              _FilterChip(
                label: copy.text('shared.all'),
                icon: Icons.grid_view_rounded,
                selected: selectedCategory == null,
                onTap: () => onCategorySelected(null),
              ),
              for (final category in categories) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: copy.communityCategory(category.name),
                  icon: _categoryIcon(category),
                  selected: selectedCategory == category,
                  onTap: () => onCategorySelected(category),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    final foreground = selected ? Colors.white : AppThemeColors.muted;
    return Material(
      color: selected ? _communityBlue : AppThemeColors.surfaceAlt,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedStrip extends StatelessWidget {
  const _FeaturedStrip({required this.items, required this.onOpen});

  final List<CommunityItem> items;
  final ValueChanged<CommunityItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  copy.text('community.worthLook'),
                  style: TextStyle(
                    color: AppThemeColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 17,
                  color: AppThemeColors.accentGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 136,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 11),
              itemBuilder: (context, index) {
                final item = items[index];
                final accent = _categoryColour(item.category);
                return SizedBox(
                  width: 246,
                  child: Material(
                    color: accent.withValues(
                      alpha: AppThemeColors.isDark ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(23),
                    child: InkWell(
                      onTap: () => onOpen(item),
                      borderRadius: BorderRadius.circular(23),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _categoryIcon(item.category),
                                  size: 18,
                                  color: accent,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    copy
                                        .communityCategory(item.category.name)
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 9,
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_outward_rounded,
                                  color: accent,
                                  size: 17,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppThemeColors.text,
                                fontSize: 16,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              item.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppThemeColors.subtleText,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsHeading extends StatelessWidget {
  const _ResultsHeading({
    required this.count,
    required this.category,
    required this.query,
    required this.hasActiveFilters,
    required this.onClear,
  });

  final int count;
  final CommunityCategory? category;
  final String query;
  final bool hasActiveFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    final title =
        (category == null ? null : copy.communityCategory(category!.name)) ??
        (query.trim().isEmpty
            ? copy.text('community.guide')
            : copy.text('community.searchResults'));
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppThemeColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          count == 1
              ? copy.text('community.resultOne')
              : copy.text('community.resultsMany', {'count': count}),
          style: TextStyle(
            color: AppThemeColors.subtleText,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (hasActiveFilters) ...[
          const SizedBox(width: 7),
          IconButton(
            tooltip: copy.text('shared.clearFilters'),
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: Icon(
              Icons.filter_alt_off_rounded,
              color: AppThemeColors.muted,
              size: 20,
            ),
          ),
        ],
      ],
    );
  }
}

class _CommunityListItem extends StatelessWidget {
  const _CommunityListItem({required this.item, required this.onTap});

  final CommunityItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryColour(item.category);
    final copy = CommunityServicesLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: AppThemeColors.isDark ? 0.19 : 0.11,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _categoryIcon(item.category),
                  color: accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          copy.communityCategory(item.category.name),
                          style: TextStyle(
                            color: accent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (item.featured) ...[
                          const SizedBox(width: 7),
                          Icon(Icons.star_rounded, color: accent, size: 12),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppThemeColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppThemeColors.subtleText,
                        fontSize: 10.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: AppThemeColors.muted,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppThemeColors.muted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 38),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppThemeColors.muted,
                  size: 22,
                ),
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 42, color: AppThemeColors.muted),
          const SizedBox(height: 13),
          Text(
            copy.text('community.noMatches'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppThemeColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            copy.text('community.trySearch'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppThemeColors.subtleText, height: 1.4),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(copy.text('community.showEverything')),
          ),
        ],
      ),
    );
  }
}

class _OfficialSourceFooter extends StatelessWidget {
  const _OfficialSourceFooter();

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: AppThemeColors.accentGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  copy.text('community.trustNotice'),
                  style: TextStyle(
                    color: AppThemeColors.subtleText,
                    fontSize: 9.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityDetailSheet extends StatelessWidget {
  const _CommunityDetailSheet({required this.item, required this.onOpenLink});

  final CommunityItem item;
  final VoidCallback onOpenLink;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryColour(item.category);
    final copy = CommunityServicesLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppThemeColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppThemeColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _categoryIcon(item.category),
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  copy
                                      .communityCategory(item.category.name)
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 9,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    color: AppThemeColors.text,
                                    fontSize: 23,
                                    height: 1.1,
                                    letterSpacing: -0.4,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: copy.text('shared.close'),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        item.summary,
                        style: TextStyle(
                          color: AppThemeColors.text,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.details,
                        style: TextStyle(
                          color: AppThemeColors.subtleText,
                          fontSize: 12,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 21),
                      _DetailFacts(item: item, accent: accent),
                      if (item.tags.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final tag in item.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppThemeColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: AppThemeColors.muted,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      Divider(color: AppThemeColors.border),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: AppThemeColors.accentGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  copy.text('shared.officialSource'),
                                  style: TextStyle(
                                    color: AppThemeColors.text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.sourceLabel,
                                  style: TextStyle(
                                    color: AppThemeColors.subtleText,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            copy.text('community.checked', {
                              'date': MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(item.verifiedOn),
                            }),
                            style: TextStyle(
                              color: AppThemeColors.subtleText,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        item.officialUrl,
                        style: TextStyle(
                          color: AppThemeColors.accentCyan,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onOpenLink,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppThemeColors.accentGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(
                            item.actionLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w900),
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
      ),
    );
  }
}

class _DetailFacts extends StatelessWidget {
  const _DetailFacts({required this.item, required this.accent});

  final CommunityItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    final facts = <({IconData icon, String label, String value})>[
      (
        icon: Icons.location_on_outlined,
        label: copy.text('community.where'),
        value: item.location,
      ),
      (
        icon: Icons.schedule_rounded,
        label: copy.text('community.when'),
        value: item.schedule,
      ),
      (
        icon: Icons.payments_outlined,
        label: copy.text('community.cost'),
        value: item.cost,
      ),
      (
        icon: Icons.groups_2_outlined,
        label: copy.text('community.goodFor'),
        value: item.audience,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 2 : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final fact in facts)
              SizedBox(
                width: width,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(fact.icon, color: accent, size: 18),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fact.label.toUpperCase(),
                            style: TextStyle(
                              color: AppThemeColors.muted,
                              fontSize: 8,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            fact.value,
                            style: TextStyle(
                              color: AppThemeColors.text,
                              fontSize: 10.5,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CommunityLoading extends StatelessWidget {
  const _CommunityLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppThemeColors.accentGreen),
          const SizedBox(height: 15),
          Text(
            copy.text('community.loading'),
            style: TextStyle(
              color: AppThemeColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityError extends StatelessWidget {
  const _CommunityError({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = CommunityServicesLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: AppThemeColors.accentCyan,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              copy.text('community.unavailable'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppThemeColors.text,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              copy.text('community.loadError'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppThemeColors.subtleText, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(copy.text('shared.tryAgain')),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _categoryIcon(CommunityCategory category) => switch (category) {
  CommunityCategory.events => Icons.calendar_month_rounded,
  CommunityCategory.library => Icons.local_library_rounded,
  CommunityCategory.sport => Icons.sports_soccer_rounded,
  CommunityCategory.walking => Icons.directions_walk_rounded,
  CommunityCategory.cycling => Icons.directions_bike_rounded,
  CommunityCategory.volunteering => Icons.volunteer_activism_rounded,
  CommunityCategory.bushcare => Icons.eco_rounded,
  CommunityCategory.festivals => Icons.celebration_rounded,
  CommunityCategory.markets => Icons.storefront_rounded,
  CommunityCategory.organisations => Icons.groups_2_rounded,
};

Color _categoryColour(CommunityCategory category) => switch (category) {
  CommunityCategory.events => const Color(0xFF9C6ADE),
  CommunityCategory.library => AppThemeColors.accentBlue,
  CommunityCategory.sport => const Color(0xFFE18122),
  CommunityCategory.walking => AppThemeColors.accentGreen,
  CommunityCategory.cycling => const Color(0xFF278CA6),
  CommunityCategory.volunteering => const Color(0xFFD5587D),
  CommunityCategory.bushcare => const Color(0xFF4E9953),
  CommunityCategory.festivals => const Color(0xFFD56E28),
  CommunityCategory.markets => const Color(0xFFB88A14),
  CommunityCategory.organisations => const Color(0xFF4779D2),
};
