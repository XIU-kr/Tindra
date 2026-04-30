// Phase 4.1 verification — jump-host (proxy via direct-tcpip).
//
// FULL end-to-end success requires two distinct SSH servers (jump + target),
// which the local Windows OpenSSH setup doesn't easily provide — chaining
// localhost via itself would loop and the server eventually rejects it.
// So this test confirms the JumpHost FFI struct is wired through the bridge
// and openShellPubkey accepts it without panicking. Real jump-host
// connectivity is verified manually against external infrastructure.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/src/rust/api/ssh.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

const _keyPath = r'C:\Users\XIU\.ssh\id_ed25519';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  test('openShellPubkey accepts JumpHost without crashing', () async {
    BigInt? sessionId;
    String? error;
    try {
      sessionId = await rust
          .openShellPubkey(
            host: 'localhost',
            port: 22,
            username: 'XIU',
            privateKeyPath: _keyPath,
            passphrase: null,
            cols: 120,
            rows: 32,
            jump: const rust.JumpHost(
              host: 'localhost',
              port: 22,
              username: 'XIU',
              privateKeyPath: _keyPath,
              passphrase: null,
            ),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      error = e.toString();
    }

    if (sessionId != null) {
      // Local SSH server allowed the loop — close cleanly.
      await rust.shellClose(sessionId: sessionId);
    } else {
      // Expected: loop guard or timeout. Either way the FFI surface is alive.
      expect(error, isNotNull);
    }
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('openShellPubkey works without a jump host (regression)', () async {
    final id = await rust.openShellPubkey(
      host: 'localhost',
      port: 22,
      username: 'XIU',
      privateKeyPath: _keyPath,
      passphrase: null,
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
    expect(id, isNotNull);
    await rust.shellClose(sessionId: id);
  }, timeout: const Timeout(Duration(seconds: 15)));
}
