import 'dart:io';

import 'package:tindra_desktop/main.dart';
import 'package:tindra_desktop/src/rust/api/profiles.dart' as profiles_api;
import 'package:tindra_desktop/src/rust/api/settings.dart' as settings_api;
import 'package:tindra_desktop/src/rust/api/ssh.dart' as ssh_api;

class AppDataSnapshot {
  AppDataSnapshot._(this._files);

  final Map<String, String?> _files;

  static Future<AppDataSnapshot> capture() async {
    final appDataDir = File(await profiles_api.profilesPath()).parent;
    final files = <String, String?>{};
    for (final name in const [
      'profiles.json',
      'settings.json',
      'desktop_state.json',
    ]) {
      final file = File('${appDataDir.path}/$name');
      files[file.path] = file.existsSync() ? file.readAsStringSync() : null;
    }
    return AppDataSnapshot._(files);
  }

  Future<void> clearDesktopState() async {
    final statePath = _files.keys.firstWhere(
      (path) => path.endsWith('desktop_state.json'),
    );
    final state = File(statePath);
    if (state.existsSync()) state.deleteSync();
  }

  Future<void> restore() async {
    for (final entry in _files.entries) {
      final file = File(entry.key);
      final contents = entry.value;
      if (contents == null) {
        if (file.existsSync()) file.deleteSync();
      } else {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(contents);
      }
    }
  }
}

Future<void> isolateProfiles(List<profiles_api.Profile> profiles) async {
  for (final p in await profiles_api.listProfiles()) {
    await profiles_api.deleteProfile(id: p.id);
  }
  for (final p in profiles) {
    await profiles_api.upsertProfile(profile: p);
  }
}

Future<void> useEnglishTestSettings() async {
  final settings = appSettings.value;
  final wanted = settings_api.Settings(
    theme: settings.theme,
    fontFamily: settings.fontFamily,
    fontSize: settings.fontSize,
    quakeHotkey: settings.quakeHotkey,
    locale: 'en',
    localShell: settings.localShell,
    localShellCwd: settings.localShellCwd,
    localShellEnv: settings.localShellEnv,
  );
  await settings_api.saveSettings(settings: wanted);
  appSettings.value = wanted;
}

Future<void> trustLocalhostHostKey() async {
  final check = await ssh_api.probeHostKey(host: 'localhost', port: 22);
  if (check.status == 'trusted') return;
  if (check.status == 'changed') {
    await profiles_api.deleteHostKey(host: 'localhost', port: 22);
  }
  await profiles_api.trustHostKey(
    host: 'localhost',
    port: 22,
    fingerprint: check.actual,
  );
}
