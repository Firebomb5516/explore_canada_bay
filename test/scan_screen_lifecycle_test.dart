import 'package:explore_canada_bay/models/passport.dart';
import 'package:explore_canada_bay/screens/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('inactive Scan tab never mounts the camera', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: ScanScreen(
          passport: PassportController(store: _MemoryPassportStore()),
          isActive: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MobileScanner), findsNothing);
    expect(find.text('Scan & Discover'), findsOneWidget);

    final enterCode = find.text('Enter code');
    await tester.ensureVisible(enterCode);
    await tester.pumpAndSettle();
    await tester.tap(enterCode);
    await tester.pumpAndSettle();

    expect(find.text('Enter a reward code'), findsNothing);
    expect(find.byType(MobileScanner), findsNothing);
  });

  testWidgets('paused app never mounts an active Scan camera', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: ScanScreen(
          passport: PassportController(store: _MemoryPassportStore()),
          isActive: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MobileScanner), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('inactive scanner layout is responsive', (tester) async {
    for (final size in <Size>[const Size(390, 844), const Size(1280, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ScanScreen(
            passport: PassportController(store: _MemoryPassportStore()),
            isActive: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Scan & Discover'), findsOneWidget);
      expect(find.byType(MobileScanner), findsNothing);
      expect(tester.takeException(), isNull);
    }

    await tester.binding.setSurfaceSize(null);
  });
}

class _MemoryPassportStore implements PassportStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
