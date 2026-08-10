import 'package:flutter/material.dart';

/// Shared semantic colours for every app surface.
///
/// Brand colours remain stable while structural colours adapt to the selected
/// theme. [mode] is set by the root app before descendant pages are built.
abstract final class AppThemeColors {
  static ThemeMode mode = ThemeMode.light;

  static bool get isDark {
    return switch (mode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
  }

  static Color get background =>
      isDark ? const Color(0xFF061C31) : const Color(0xFFFFFFFF);

  static Color get backgroundAlt =>
      isDark ? const Color(0xFF071E35) : const Color(0xFFF6F9FA);

  static Color get glow =>
      isDark ? const Color(0xFF0B3655) : const Color(0xFFE7F5F2);

  static Color get surface =>
      isDark ? const Color(0xFF0B2A45) : const Color(0xFFFFFFFF);

  static Color get surfaceAlt =>
      isDark ? const Color(0xFF123653) : const Color(0xFFF2F7F8);

  static Color get surfaceStrong =>
      isDark ? const Color(0xFF0B304E) : const Color(0xFFE8F1F3);

  static Color get text =>
      isDark ? const Color(0xFFF4F9FD) : const Color(0xFF102A3A);

  static Color get muted =>
      isDark ? const Color(0xFF7DCCDC) : const Color(0xFF557787);

  static Color get subtleText =>
      isDark ? const Color(0xFF9AB5C7) : const Color(0xFF688491);

  static Color get accentGreen =>
      isDark ? const Color(0xFF00C58E) : const Color(0xFF007D59);

  static Color get accentBlue =>
      isDark ? const Color(0xFF2587D9) : const Color(0xFF1769AA);

  static Color get accentCyan =>
      isDark ? const Color(0xFF65CDE1) : const Color(0xFF1C7286);

  static Color get border =>
      isDark ? const Color(0x332587D9) : const Color(0x260D4F7C);

  static Color get shadow =>
      Colors.black.withValues(alpha: isDark ? 0.22 : 0.08);
}
