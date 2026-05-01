// Phase 5 verification — local port forwarding end-to-end.
//
// Strategy: spin up an in-process TCP echo server on a random local port,
// open a forward (127.0.0.1:0 → 127.0.0.1:echoPort), connect to the
// forward's local end, send bytes, and read them back. If the forward
// works, the bytes round-trip through SSH and the echo server.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/src/rust/api/forward.dart' as rust;
import 'package:tindra_desktop/src/rust/api/ssh.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

const _keyPath = r'C:\Users\XIU\.ssh\id_ed25519';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  test('local forward: send → SSH tunnel → echo server → receive',
      () async {
    final user = Platform.environment['USERNAME'] ?? 'XIU';

    // 1) Start a tiny TCP echo server on an ephemeral port.
    final echoServer =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final echoSubs = <StreamSubscription>[];
    final echoSub = echoServer.listen((conn) {
      final s = conn.listen((data) => conn.add(data));
      echoSubs.add(s);
    });
    addTearDown(() async {
      await echoSub.cancel();
      for (final s in echoSubs) {
        await s.cancel();
      }
      await echoServer.close();
    });

    // 2) Open the forward through SSH.
    final forwardId = await rust.openLocalForwardPubkey(
      host: 'localhost',
      port: 22,
      username: user,
      privateKeyPath: _keyPath,
      passphrase: null,
      jump: const rust.JumpHost(
        host: '',
        port: 22,
        username: '',
        privateKeyPath: '',
        passphrase: null,
      ),
      localAddr: '127.0.0.1',
      localPort: 0, // ephemeral
      remoteHost: '127.0.0.1',
      remotePort: echoServer.port,
    );

    final forwards = await rust.listForwards();
    final f = forwards.firstWhere((e) => e.id == forwardId);
    expect(f.localPort, isNot(0),
        reason: 'forward should bind a real ephemeral port');

    // 3) Connect through the forward and round-trip.
    final client = await Socket.connect('127.0.0.1', f.localPort);
    final received = BytesBuilder();
    final completer = Completer<void>();
    final clientSub = client.listen(
      received.add,
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
    );

    final payload = Uint8List.fromList('TINDRA-FORWARD-OK\n'.codeUnits);
    client.add(payload);
    await client.flush();

    // Wait until echoed bytes arrive (or timeout).
    final start = DateTime.now();
    while (received.length < payload.length &&
        DateTime.now().difference(start) < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await client.close();
    await clientSub.cancel();

    expect(received.takeBytes(), payload,
        reason: 'echo bytes should match what we sent');

    await rust.stopForward(id: forwardId);
    final after = await rust.listForwards();
    expect(after.any((e) => e.id == forwardId), isFalse,
        reason: 'stop should remove the forward from the registry');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
