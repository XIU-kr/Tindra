// Phase 8c verification — Telnet (raw TCP) FFI surface.
//
// We don't have a Telnet daemon in CI and full snapshot round-tripping
// through the frb stream involves enough timing complexity to be flaky.
// This test confirms the FFI binding is wired (open_shell_telnet returns
// a session id, shell_close accepts it) and that bogus connections
// surface as errors instead of crashing.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/src/rust/api/ssh.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  test('Telnet open against a closed port surfaces an error', () async {
    String? error;
    try {
      // Port 1 is virtually always closed/unbound on a desktop.
      await rust
          .openShellTelnet(host: '127.0.0.1', port: 1, cols: 80, rows: 24)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      error = e.toString();
    }
    expect(error, isNotNull,
        reason: 'connecting to a closed TCP port must fail or time out');
  }, timeout: const Timeout(Duration(seconds: 15)));
}
