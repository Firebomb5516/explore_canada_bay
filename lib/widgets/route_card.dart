import 'package:flutter/material.dart' hide Text;

import 'localized_text.dart';

const _kGreen = Color(0xFF00B87A);
const _kCardSurface = Color(0xFF173238);
const _kCardSurfaceHover = Color(0xFF1D3D42);
const _kCardText = Color(0xFFF3F8F5);
const _kCardMuted = Color(0xFFA5BDB8);
const _kCardBorder = Color(0xFF47615D);

class RouteCard extends StatefulWidget {
  final Map<String, dynamic> route;
  final bool compact;
  final VoidCallback? onTap;

  const RouteCard({
    super.key,
    required this.route,
    this.compact = false,
    this.onTap,
  });

  @override
  State<RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<RouteCard> {
  bool _hovering = false;
  bool _pressing = false;

  String _asString(dynamic value, String fallback) {
    if (value == null) return fallback;
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;

    final title = _asString(route['title'], 'Route');
    final category = _asString(route['category'], 'Walking');
    final image = _asString(route['image'], '');
    final duration = _asString(route['duration'], '--');
    final distance = _asString(route['distance'], '--');
    final difficulty = _asString(route['difficulty'], 'Easy');
    final stops = _asString(route['stops'], '--');
    final rating = _asString(route['rating'], '--');
    final xp = _asString(route['xp'], '0');

    final scale = _pressing
        ? 0.985
        : _hovering
        ? 1.012
        : 1.0;

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovering = false;
          _pressing = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: widget.onTap == null
            ? null
            : (_) {
                setState(() {
                  _pressing = true;
                });
              },
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                setState(() {
                  _pressing = false;
                });
              },
        onTapCancel: widget.onTap == null
            ? null
            : () {
                setState(() {
                  _pressing = false;
                });
              },
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _hovering ? _kCardSurfaceHover : _kCardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _hovering
                    ? _kGreen.withValues(alpha: 0.72)
                    : _kCardBorder.withValues(alpha: 0.72),
                width: _hovering ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _hovering ? 0.28 : 0.16,
                  ),
                  blurRadius: _hovering ? 22 : 13,
                  offset: Offset(0, _hovering ? 10 : 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.compact
                ? _buildCompact(
                    title: title,
                    category: category,
                    image: image,
                    duration: duration,
                    distance: distance,
                    difficulty: difficulty,
                    stops: stops,
                    rating: rating,
                    xp: xp,
                  )
                : _buildFull(
                    title: title,
                    category: category,
                    image: image,
                    duration: duration,
                    distance: distance,
                    difficulty: difficulty,
                    stops: stops,
                    rating: rating,
                    xp: xp,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFull({
    required String title,
    required String category,
    required String image,
    required String duration,
    required String distance,
    required String difficulty,
    required String stops,
    required String rating,
    required String xp,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 165,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _routeImage(image),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.68),
                    ],
                    stops: const [0, 0.52, 1],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: _CategoryPill(category: category),
              ),
              Positioned(top: 14, right: 14, child: _XpPill(xp: xp)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kCardText,
                  fontSize: 21,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 13,
                runSpacing: 9,
                children: [
                  _MetaItem(icon: Icons.schedule_rounded, label: duration),
                  _MetaItem(icon: Icons.navigation_outlined, label: distance),
                  _MetaItem(icon: Icons.place_outlined, label: '$stops stops'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _DifficultyPill(label: difficulty),
                  const SizedBox(width: 10),
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    rating,
                    style: const TextStyle(
                      color: _kCardMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  _LoadRouteButton(onTap: widget.onTap),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompact({
    required String title,
    required String category,
    required String image,
    required String duration,
    required String distance,
    required String difficulty,
    required String stops,
    required String rating,
    required String xp,
  }) {
    return SizedBox(
      height: 148,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 5,
            height: double.infinity,
            color: _hovering ? _kGreen : _kGreen.withValues(alpha: 0.52),
          ),
          SizedBox(
            width: 132,
            height: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _routeImage(image),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.58),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: _CategoryPill(category: category),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 13, 14, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _kCardText,
                            fontSize: 17,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _XpPill(xp: xp),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 10,
                    runSpacing: 7,
                    children: [
                      _MetaItem(icon: Icons.schedule_rounded, label: duration),
                      _MetaItem(
                        icon: Icons.navigation_outlined,
                        label: distance,
                      ),
                      _MetaItem(
                        icon: Icons.place_outlined,
                        label: '$stops stops',
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _DifficultyPill(label: difficulty),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          color: _kCardMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      _LoadRouteButton(onTap: widget.onTap),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeImage(String image) {
    if (image.isEmpty) {
      return _imageFallback();
    }

    return Image.asset(
      image,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return _imageFallback();
      },
    );
  }

  Widget _imageFallback() {
    return ColoredBox(
      color: const Color(0xFF0D4F7C),
      child: const Center(
        child: Icon(Icons.route_rounded, color: Colors.white, size: 42),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String category;

  const _CategoryPill({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF102528).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForCategory(category), color: _kGreen, size: 13),
          const SizedBox(width: 5),
          Text(
            category.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    final value = category.toLowerCase();

    if (value.contains('walking')) {
      return Icons.directions_walk_rounded;
    }

    if (value.contains('cycling')) {
      return Icons.directions_bike_rounded;
    }

    if (value.contains('running')) {
      return Icons.directions_run_rounded;
    }

    return Icons.route_rounded;
  }
}

class _XpPill extends StatelessWidget {
  final String xp;

  const _XpPill({required this.xp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kGreen.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: _kGreen, size: 13),
          const SizedBox(width: 3),
          Text(
            '+$xp XP',
            style: const TextStyle(
              color: _kGreen,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _kCardMuted, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: _kCardMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DifficultyPill extends StatelessWidget {
  final String label;

  const _DifficultyPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final value = label.toLowerCase();

    final Color color = value.contains('hard')
        ? Colors.redAccent
        : value.contains('moderate')
        ? Colors.orangeAccent
        : _kGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LoadRouteButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _LoadRouteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: enabled ? _kGreen : _kCardMuted.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                enabled ? 'Load route' : 'Unavailable',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
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
