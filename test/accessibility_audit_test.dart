import 'package:explore_canada_bay/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic text colours meet WCAG AA contrast on app surfaces', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      AppThemeColors.mode = mode;
      final surfaces = [
        AppThemeColors.background,
        AppThemeColors.surface,
        AppThemeColors.surfaceAlt,
        AppThemeColors.surfaceStrong,
      ];
      final textColours = [
        AppThemeColors.text,
        AppThemeColors.muted,
        AppThemeColors.subtleText,
      ];

      for (final foreground in textColours) {
        for (final background in surfaces) {
          expect(
            _contrastRatio(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason:
                '${mode.name}: ${foreground.toARGB32().toRadixString(16)} '
                'on ${background.toARGB32().toRadixString(16)}',
          );
        }
      }
    }
    AppThemeColors.mode = ThemeMode.light;
  });

  testWidgets('Material controls use padded 48 pixel touch targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ),
        home: Scaffold(
          body: FilledButton(onPressed: () {}, child: const Text('Action')),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );
  });
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = _luminance(foreground) >= _luminance(background)
      ? foreground
      : background;
  final darker = lighter == foreground ? background : foreground;
  return (_luminance(lighter) + 0.05) / (_luminance(darker) + 0.05);
}

double _luminance(Color colour) => colour.computeLuminance();
