// Phase 7 verification — Settings persistence and shortcuts.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/main.dart';
import 'package:tindra_desktop/src/rust/api/profiles.dart' as rust;
import 'package:tindra_desktop/src/rust/api/settings.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

const _profileName = 'shortcuts-test-profile';
const _keyPath = r'C:\Users\XIU\.ssh\id_ed25519';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late File settingsFile;
  late rust.Settings backupSettings;
  late List<rust.Profile> backupProfiles;

  setUpAll(() async {
    await RustLib.init();
    final appDataDir = File(await rust.profilesPath()).parent;
    settingsFile = File('${appDataDir.path}/settings.json');
    backupSettings = await rust.loadSettings();
    backupProfiles = await rust.listProfiles();
    for (final p in backupProfiles) {
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
  });

  tearDownAll(() async {
    await rust.saveSettings(settings: backupSettings);
    appSettings.value = backupSettings;
    for (final p in await rust.listProfiles()) {
      await rust.deleteProfile(id: p.id);
    }
    for (final p in backupProfiles) {
      await rust.upsertProfile(profile: p);
    }
  });

  test('Settings round-trip: save → file on disk → load returns same values',
      () async {
    final wanted = const rust.Settings(
      theme: 'light',
      fontFamily: 'Cascadia Mono',
      fontSize: 16.0,
      quakeHotkey: 'F12',
    );
    await rust.saveSettings(settings: wanted);
    expect(settingsFile.existsSync(), isTrue,
        reason: 'settings.json should be created');

    final loaded = await rust.loadSettings();
    expect(loaded.theme, 'light');
    expect(loaded.fontFamily, 'Cascadia Mono');
    expect(loaded.fontSize, 16.0);
    expect(loaded.quakeHotkey, 'F12');
  });

  test('Settings load returns defaults when file missing', () async {
    if (settingsFile.existsSync()) settingsFile.deleteSync();
    final loaded = await rust.loadSettings();
    expect(loaded.theme, 'dark');
    expect(loaded.fontFamily, 'Consolas');
    expect(loaded.fontSize, 13.0);
  });

  testWidgets('Ctrl+T opens a new tab; Ctrl+W closes it', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const TindraApp());
    await _settle(tester,
        predicate: () => find.text(_profileName).evaluate().isNotEmpty);

    expect(_visibleTabCount(tester), 0,
        reason: 'no tabs at startup');

    // Ctrl+T → opens a tab on the selected profile.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    await _settle(
      tester,
      timeout: const Duration(seconds: 15),
      predicate: () => _visibleTabCount(tester) == 1,
    );
    expect(_visibleTabCount(tester), 1, reason: 'Ctrl+T should open a tab');

    // Ctrl+W → closes the active tab.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    await _settle(
      tester,
      timeout: const Duration(seconds: 5),
      predicate: () => _visibleTabCount(tester) == 0,
    );
    expect(_visibleTabCount(tester), 0,
        reason: 'Ctrl+W should close the only tab');
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

int _visibleTabCount(WidgetTester tester) {
  final dots = tester.widgetList<Container>(find.byType(Container)).where((c) {
    final box = c.constraints;
    if (box == null) return false;
    return box.maxWidth == 6 && box.maxHeight == 6;
  });
  return dots.length;
}
