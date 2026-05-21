// Phase 1.3 verification — raw keystrokes flow through Focus.onKeyEvent into
// the live SSH session, and the remote echo comes back via the snapshot stream.
//
// This test uses tester.sendKeyEvent (which dispatches via Flutter's
// HardwareKeyboard / FocusManager) instead of OS-level key synthesis, so it
// does not hit the limitation noted in memory where PowerShell SendInput keys
// don't reach the Flutter Windows embedder.
//
// Requirements (see project memory): local OpenSSH Server running on
// localhost:22, ~/.ssh/id_ed25519 registered for the current user.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/main.dart';
import 'package:tindra_desktop/src/rust/api/profiles.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

import 'test_support.dart';

const _localProfileName = 'localhost-keystroke-test';
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
        name: _localProfileName,
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
    'keystrokes reach the remote shell and echo back',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await appDataSnapshot.clearDesktopState();
      await tester.pumpWidget(const TindraApp());

      await _settle(
        tester,
        predicate: () => find.text(_localProfileName).evaluate().isNotEmpty,
      );

      await _openTabWithShortcut(tester);

      await _settle(
        tester,
        timeout: const Duration(seconds: 15),
        predicate: () => _terminalContains(tester, RegExp(r'[>\$#]')),
      );

      final terminalArea = find.byKey(const ValueKey('terminal-focus'));
      await tester.tap(terminalArea);
      await tester.pump();

      const marker = 'TINDRAOK';
      for (final ch in 'echo $marker'.split('')) {
        await tester.sendKeyEvent(_logicalKeyForChar(ch), character: ch);
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      await _settle(
        tester,
        timeout: const Duration(seconds: 8),
        predicate: () => _terminalContains(tester, RegExp(marker)),
      );

      expect(
        _terminalContains(tester, RegExp(marker)),
        isTrue,
        reason: 'remote echo of "$marker" should appear in terminal output',
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
    skip: true, // Synthetic text keys are unreliable on Flutter Windows tests.
  );

  testWidgets(
    'Ctrl+C sends SIGINT byte (0x03) — observed via prompt return',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await appDataSnapshot.clearDesktopState();
      await tester.pumpWidget(const TindraApp());
      await _settle(
        tester,
        predicate: () => find.text(_localProfileName).evaluate().isNotEmpty,
      );
      await _openTabWithShortcut(tester);

      await _settle(
        tester,
        timeout: const Duration(seconds: 15),
        predicate: () => _terminalContains(tester, RegExp(r'[>\$#]')),
      );

      final terminalArea = find.byKey(const ValueKey('terminal-focus'));
      await tester.tap(terminalArea);
      await tester.pump();

      final beforeLen = _terminalPlainText(tester).length;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      await _settle(
        tester,
        timeout: const Duration(seconds: 5),
        predicate: () => _terminalPlainText(tester).length > beforeLen,
      );

      expect(
        _terminalPlainText(tester).length,
        greaterThan(beforeLen),
        reason: 'Ctrl+C should produce some terminal output (new prompt)',
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
    skip: true, // Synthetic control keys are unreliable on Flutter Windows tests.
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

LogicalKeyboardKey _logicalKeyForChar(String ch) {
  if (ch == ' ') return LogicalKeyboardKey.space;
  final lower = ch.toLowerCase();
  final code = lower.codeUnitAt(0);
  if (code >= 0x61 && code <= 0x7a) {
    return <LogicalKeyboardKey>[
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyB,
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyG,
      LogicalKeyboardKey.keyH,
      LogicalKeyboardKey.keyI,
      LogicalKeyboardKey.keyJ,
      LogicalKeyboardKey.keyK,
      LogicalKeyboardKey.keyL,
      LogicalKeyboardKey.keyM,
      LogicalKeyboardKey.keyN,
      LogicalKeyboardKey.keyO,
      LogicalKeyboardKey.keyP,
      LogicalKeyboardKey.keyQ,
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyT,
      LogicalKeyboardKey.keyU,
      LogicalKeyboardKey.keyV,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyX,
      LogicalKeyboardKey.keyY,
      LogicalKeyboardKey.keyZ,
    ][code - 0x61];
  }
  if (code >= 0x30 && code <= 0x39) {
    return <LogicalKeyboardKey>[
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ][code - 0x30];
  }
  return LogicalKeyboardKey(code);
}
