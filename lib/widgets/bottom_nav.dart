import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final destinations = <_Destination>[
      _Destination(
        label: strings.text('home'),
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _Destination(
        label: strings.text('explore'),
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
      ),
      _Destination(
        label: strings.text('community'),
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups_rounded,
      ),
      _Destination(
        label: strings.text('services'),
        icon: Icons.account_balance_outlined,
        selectedIcon: Icons.account_balance_rounded,
      ),
      _Destination(
        label: strings.text('passport'),
        icon: Icons.auto_stories_outlined,
        selectedIcon: Icons.auto_stories_rounded,
      ),
    ];

    return Material(
      color: AppThemeColors.surface,
      elevation: 16,
      shadowColor: AppThemeColors.shadow,
      child: SafeArea(
        top: false,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppThemeColors.border)),
          ),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _NavDestination(
                    destination: destinations[index],
                    selected: selectedIndex == index,
                    onTap: () => onTap(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavDestination extends StatefulWidget {
  const _NavDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavDestination> createState() => _NavDestinationState();
}

class _NavDestinationState extends State<_NavDestination> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? AppThemeColors.accentGreen
        : AppThemeColors.muted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.destination.label,
        child: InkWell(
          onTap: widget.onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                top: 0,
                left: widget.selected ? 18 : 40,
                right: widget.selected ? 18 : 40,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: widget.selected ? 3 : 0,
                  color: AppThemeColors.accentGreen,
                ),
              ),
              AnimatedScale(
                scale: _hovering ? 1.04 : 1,
                duration: const Duration(milliseconds: 140),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.selected
                          ? widget.destination.selectedIcon
                          : widget.destination.icon,
                      color: color,
                      size: widget.selected ? 25 : 23,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: widget.selected
                            ? FontWeight.w900
                            : FontWeight.w700,
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

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
