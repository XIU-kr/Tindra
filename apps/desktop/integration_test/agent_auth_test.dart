// Phase 4.0 verification — SSH agent authentication.
//
// The agent path is reachable from Dart (FFI binding generated, profile
// model carries auth_method, UI dispatches to openShellAgent). This test
// confirms the call chain works end-to-end. If the local ssh-agent service
// isn't running or has no identities loaded (the default on Windows), the
// test verifies that we surface a clear error instead of crashing — the
// user will see "ssh-agent unavailable" or "no identities" in the UI.
//
// To exercise the success path on Windows:
//   Set-Service ssh-agent -StartupType Automatic
//   Start-Service ssh-agent
//   ssh-add C:\Users\XIU\.ssh\id_ed25519

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/src/rust/api/ssh.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  test('openShellAgent surfaces agent state without crashing', () async {
    BigInt? sessionId;
    String? error;
    try {
      sessionId = await rust.openShellAgent(
        host: 'localhost',
        port: 22,
        username: 'XIU',
        cols: 120,
        rows: 32,
        jump: const rust.JumpHost(
          host: '',
          port: 22,
          username: '',
          privateKeyPath: '',
          passphrase: null,
        ),
      );
    } catch (e) {
      error = e.toString();
    }

    if (sessionId != null) {
      // Success path — agent is up, key is added, server accepted it.
      expect(sessionId, isNotNull);
      await rust.shellClose(sessionId: sessionId);
    } else {
      // Expected when ssh-agent isn't running or has no identities. The
      // exact message comes from tindra-ssh's SshError variants.
      expect(error, isNotNull);
      expect(
        error!.toLowerCase(),
        anyOf(
          contains('agent'),
          contains('pipe'),
          contains('identities'),
          contains('authentication failed'),
        ),
        reason: 'agent failure should produce a recognisable error',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 15)));
}
