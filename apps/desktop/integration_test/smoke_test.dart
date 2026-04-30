// Smoke test — verifies that the integration_test harness boots, the Rust
// dynamic library loads, and the FFI surface is reachable. If this passes,
// the rest of the integration suite has a working environment.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/src/rust/api/profiles.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  test('Rust FFI: profilesPath() returns a non-empty path', () async {
    final path = await rust.profilesPath();
    expect(path, isNotEmpty);
    expect(path.toLowerCase(), contains('tindra'));
  });

  test('Rust FFI: listProfiles() returns a list (possibly empty)', () async {
    final list = await rust.listProfiles();
    expect(list, isA<List<rust.Profile>>());
  });
}
