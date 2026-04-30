// Phase 2 verification — profile manager CRUD against the real on-disk store.
//
// The Rust store keeps an in-memory cache (OnceLock<Mutex<...>>), so we can't
// just delete profiles.json on disk to isolate the test — the cache would
// still serve the previous contents. Instead we drain the store via the API,
// run the test, and restore the user's pre-existing profiles via the API.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/src/rust/api/profiles.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late File storeFile;
  late List<rust.Profile> originalProfiles;

  setUpAll(() async {
    await RustLib.init();
    storeFile = File(await rust.profilesPath());
    originalProfiles = await rust.listProfiles();
    for (final p in originalProfiles) {
      await rust.deleteProfile(id: p.id);
    }
    expect(await rust.listProfiles(), isEmpty,
        reason: 'pre-test wipe should have emptied the store');
  });

  tearDownAll(() async {
    for (final p in await rust.listProfiles()) {
      await rust.deleteProfile(id: p.id);
    }
    for (final p in originalProfiles) {
      await rust.upsertProfile(profile: p);
    }
  });

  test('upsert assigns a non-empty id and persists to JSON', () async {
    final created = await rust.upsertProfile(
      profile: const rust.Profile(
        id: '',
        name: 'crud-test-1',
        host: 'localhost',
        port: 22,
        username: 'XIU',
        privateKeyPath: r'C:\Users\XIU\.ssh\id_ed25519',
        notes: 'integration test',
      ),
    );

    expect(created.id, isNotEmpty);
    expect(created.name, 'crud-test-1');

    expect(storeFile.existsSync(), isTrue, reason: 'JSON file should be written');
    final raw = jsonDecode(storeFile.readAsStringSync()) as Map<String, dynamic>;
    final profiles = (raw['profiles'] as List).cast<Map<String, dynamic>>();
    expect(profiles, hasLength(1));
    expect(profiles.first['id'], created.id);
    expect(profiles.first['notes'], 'integration test');
  });

  test('list returns all profiles, sorted by name (case-insensitive)',
      () async {
    await rust.upsertProfile(
      profile: const rust.Profile(
        id: '',
        name: 'zeta',
        host: 'h2',
        port: 22,
        username: 'u',
        privateKeyPath: 'k',
        notes: '',
      ),
    );
    await rust.upsertProfile(
      profile: const rust.Profile(
        id: '',
        name: 'alpha',
        host: 'h3',
        port: 22,
        username: 'u',
        privateKeyPath: 'k',
        notes: '',
      ),
    );

    final list = await rust.listProfiles();
    expect(list.map((p) => p.name).toList(), ['alpha', 'crud-test-1', 'zeta']);
  });

  test('upsert with existing id overwrites in place', () async {
    final list = await rust.listProfiles();
    final target = list.firstWhere((p) => p.name == 'alpha');

    final updated = await rust.upsertProfile(
      profile: rust.Profile(
        id: target.id,
        name: 'alpha-renamed',
        host: target.host,
        port: 2222,
        username: target.username,
        privateKeyPath: target.privateKeyPath,
        notes: 'edited',
      ),
    );

    expect(updated.id, target.id);
    expect(updated.port, 2222);

    final after = await rust.listProfiles();
    expect(after, hasLength(3));
    final renamed = after.firstWhere((p) => p.id == target.id);
    expect(renamed.name, 'alpha-renamed');
    expect(renamed.notes, 'edited');
  });

  test('delete removes the profile and persists the smaller list', () async {
    final before = await rust.listProfiles();
    final victim = before.firstWhere((p) => p.name == 'zeta');

    await rust.deleteProfile(id: victim.id);

    final after = await rust.listProfiles();
    expect(after, hasLength(before.length - 1));
    expect(after.any((p) => p.id == victim.id), isFalse);

    final raw = jsonDecode(storeFile.readAsStringSync()) as Map<String, dynamic>;
    final ids = (raw['profiles'] as List)
        .cast<Map<String, dynamic>>()
        .map((m) => m['id'] as String)
        .toList();
    expect(ids, isNot(contains(victim.id)));
  });

  test('delete with a non-existent id is a no-op', () async {
    final before = await rust.listProfiles();
    await rust.deleteProfile(id: 'p_does_not_exist_xyz');
    final after = await rust.listProfiles();
    expect(after.length, before.length);
  });

  test('disk and in-memory views agree (file round-trip persistence)',
      () async {
    final list = await rust.listProfiles();
    expect(list.map((p) => p.name), containsAll(['alpha-renamed', 'crud-test-1']));
    final raw = jsonDecode(storeFile.readAsStringSync()) as Map<String, dynamic>;
    final namesOnDisk = (raw['profiles'] as List)
        .cast<Map<String, dynamic>>()
        .map((m) => m['name'] as String)
        .toSet();
    final namesInMem = list.map((p) => p.name).toSet();
    expect(namesOnDisk, namesInMem);
  });
}
