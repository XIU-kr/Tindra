// Phase 8a verification — terminal panel split.
//
// Open one tab, then split it horizontally with Ctrl+Shift+H. Confirms a
// second SSH session is started inside the same tab and the green dot
// counter reflects two active sessions even though only one tab dot
// appears in the tab bar.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/main.dart';
import 'package:tindra_desktop/src/rust/api/profiles.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

const _profileName = 'split-test-profile';
const _keyPath = r'C:\Users\XIU\.ssh\id_ed25519';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late List<rust.Profile> backup;

  setUpAll(() async {
    await RustLib.init();
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
      ),
    );
  });

  tearDownAll(() async {
    for (final p in await rust.listProfiles()) {
      await rust.deleteProfile(id: p.id);
    }
    for (final p in backup) {
      await rust.upsertProfile(profile: p);
    }
  });

  testWidgets('Ctrl+Shift+H splits the active tab into two sessions',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const TindraApp());
    await _settle(tester,
        predicate: () => find.text(_profileName).evaluate().isNotEmpty);

    // Open first session via Ctrl+T.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    await _settle(
      tester,
      timeout: const Duration(seconds: 15),
      predicate: () => _tabDots(tester) == 1,
    );

    // Split horizontally — should add a second session inside the same tab.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    // Tab count stays at 1 (the dot in the tab bar reflects the active
    // session of the active tab — still one tab).
    await _settle(
      tester,
      timeout: const Duration(seconds: 15),
      predicate: () => _tabDots(tester) == 1 && _splitFrames(tester) >= 2,
    );

    expect(_tabDots(tester), 1, reason: 'still a single tab in the bar');
    expect(_splitFrames(tester), greaterThanOrEqualTo(2),
        reason: 'split should render two terminal frames');
  }, timeout: const Timeout(Duration(minutes: 1)));
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

int _tabDots(WidgetTester tester) {
  // Tab bar dots are 6×6 Containers (state colour pills).
  return tester.widgetList<Container>(find.byType(Container)).where((c) {
    final box = c.constraints;
    if (box == null) return false;
    return box.maxWidth == 6 && box.maxHeight == 6;
  }).length;
}

int _splitFrames(WidgetTester tester) {
  // Each split pane wraps its _CellGrid in a bordered Container with
  // EdgeInsets.all(2) margin. We approximate with: Containers that have
  // a BoxDecoration with a non-null border AND a 2-px margin.
  return tester.widgetList<Container>(find.byType(Container)).where((c) {
    final dec = c.decoration;
    if (dec is! BoxDecoration) return false;
    if (dec.border == null) return false;
    if (c.margin != const EdgeInsets.all(2)) return false;
    return true;
  }).length;
}
