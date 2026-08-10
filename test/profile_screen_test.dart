import 'package:explore_canada_bay/models/account_profile.dart';
import 'package:explore_canada_bay/models/app_preferences.dart';
import 'package:explore_canada_bay/screens/profile_screen.dart';
import 'package:explore_canada_bay/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppThemeColors.mode = ThemeMode.light;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('profile action rows paint ink on their panel Material', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          controller: AccountProfileController(),
          preferences: AppPreferencesController(),
        ),
      ),
    );
    await tester.pump();

    final replayAction = find.text('Replay welcome setup');
    await tester.ensureVisible(replayAction);
    await tester.pump();
    await tester.tap(replayAction);
    await tester.pumpAndSettle();

    expect(find.text('Replay welcome setup?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
