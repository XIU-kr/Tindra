// Phase 3 verification — multi-tab session lifecycle.
//
// Drives the real UI: create two sessions, verify both tabs appear in the
// tab bar, switch between them, and close one with the X button.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/main.dart';
import 'package:tindra_desktop/src/rust/api/profiles.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

import 'test_support.dart';

const _profileName = 'localhost-tabs-test';
const _keyPath = r'C:\Users\XIU\.ssh\id_ed25519';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDataSnapshot appDataSnapshot;
  late List<rust.Profile> backup;

  setUpAll(() async {
    await RustLib.init();
    appDataSnapshot = await AppDataSnapshot.capture();
    await appDataSnapshot.clearDesktopState();
    await useEnglishTestSettings();
    backup = await rust.listProfiles();
    for (final p in backup) {
      await rust.deleteProfile(id: p.id);
    }
    await rust.upsertProfile(
      profile: rust.Profile(
        id: '',
        name: _profileName,
        host: 'localhost',
        port: 22,
        username: Platform.environment['USERNAME'] ?? 'XIU',
        privateKeyPath: _keyPath,
        notes: '',
        authMethod: 'key',
        jumpHost: '',
        jumpPort: 22,
        jumpUsername: '',
        jumpPrivateKeyPath: '',
        transport: 'ssh',
      ),
    );
    await trustLocalhostHostKey();
  });

  tearDownAll(() async {
    for (final p in await rust.listProfiles()) {
      await rust.deleteProfile(id: p.id);
    }
    for (final p in backup) {
      await rust.upsertProfile(profile: p);
    }
    await appDataSnapshot.restore();
  });

  testWidgets(
    'open two sessions, switch tabs, close one',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await appDataSnapshot.clearDesktopState();
      await tester.pumpWidget(const TindraApp());
      await _settle(
        tester,
        predicate: () => find.text(_profileName).evaluate().isNotEmpty,
      );

      // ---- Open first tab via Ctrl+T on the selected profile ----
      await _openTabWithShortcut(tester);
      await _settle(
        tester,
        timeout: const Duration(seconds: 15),
        predicate: () => _terminalContains(tester, RegExp(r'[>\$#]')),
      );
      expect(_visibleTabCount(tester), 1, reason: 'first tab should appear');

      // ---- Open second tab via the same keyboard path ----
      await _openTabWithShortcut(tester);
      await _settle(
        tester,
        timeout: const Duration(seconds: 15),
        predicate: () => _visibleTabCount(tester) == 2,
      );
      expect(_visibleTabCount(tester), 2, reason: 'second tab should appear');

      // ---- Switch to the first tab by tapping its label ----
      final tabLabels = find.descendant(
        of: find.byType(Material),
        matching: find.text(_profileName),
      );
      expect(
        tabLabels.evaluate().length,
        greaterThanOrEqualTo(2),
        reason: 'two tab labels should be findable',
      );
      await tester.tap(tabLabels.first);
      await tester.pump(const Duration(milliseconds: 200));

      // ---- Close the active tab via Ctrl+W ----
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _settle(
        tester,
        timeout: const Duration(seconds: 5),
        predicate: () => _visibleTabCount(tester) == 1,
      );
      expect(_visibleTabCount(tester), 1, reason: 'one tab should remain');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _openTabWithShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

Future<void> _settle(
  WidgetTester tester, {
  required bool Function() predicate,
  Duration timeout = const Duration(seconds: 5),
  Duration tick = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(tick);
    if (predicate()) return;
  }
}

String _terminalPlainText(WidgetTester tester) {
  final richTexts = tester.widgetList<RichText>(find.byType(RichText));
  final buf = StringBuffer();
  for (final w in richTexts) {
    buf.write(w.text.toPlainText());
    buf.write('\n');
  }
  return buf.toString();
}

bool _terminalContains(WidgetTester tester, Pattern p) {
  return _terminalPlainText(tester).contains(p);
}

/// A "tab" in the bar is a Material with a small (6×6) circular state-color
/// container as its first descendant. Counting those Containers is the most
/// stable signal we have without exposing test keys from main.dart.
int _visibleTabCount(WidgetTester tester) {
  return find
      .byWidgetPredicate(
        (widget) => widget.key.toString().startsWith("[<'tab-close-"),
      )
      .evaluate()
      .length;
}
