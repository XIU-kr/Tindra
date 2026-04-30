// Phase 6 verification — SFTP MVP (open + list + upload + download +
// remove). Uses the local OpenSSH server with the test user's keys.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/src/rust/api/sftp.dart' as rust;
import 'package:tindra_desktop/src/rust/api/ssh.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

const _keyPath = r'C:\Users\XIU\.ssh\id_ed25519';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  test('SFTP round-trip: open → list → upload → download → cleanup',
      () async {
    final user = Platform.environment['USERNAME'] ?? 'XIU';
    final id = await rust.openSftpPubkey(
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
    );
    expect(id, isNotNull);

    final home = await rust.sftpHome(sessionId: id);
    expect(home, isNotEmpty);

    // Round-trip a small file: write locally, upload, list, download into
    // a different local path, compare contents.
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final marker = 'tindra-sftp-test-$stamp';
    final localUpload = File('${Directory.systemTemp.path}/$marker.up.txt');
    final localDownload = File('${Directory.systemTemp.path}/$marker.down.txt');
    final remotePath = '$home/$marker.txt';

    final payload = 'Hello from Tindra SFTP $stamp\n' * 10;
    localUpload.writeAsStringSync(payload);
    addTearDown(() {
      if (localUpload.existsSync()) localUpload.deleteSync();
      if (localDownload.existsSync()) localDownload.deleteSync();
    });

    final uploaded = await rust.sftpUpload(
      sessionId: id,
      localPath: localUpload.path,
      remotePath: remotePath,
    );
    expect(uploaded, BigInt.from(payload.length));

    final entries = await rust.sftpList(sessionId: id, path: home);
    expect(entries.any((e) => e.name == '$marker.txt'), isTrue,
        reason: 'uploaded file should appear in directory listing');

    final downloaded = await rust.sftpDownload(
      sessionId: id,
      remotePath: remotePath,
      localPath: localDownload.path,
    );
    expect(downloaded, BigInt.from(payload.length));
    expect(localDownload.readAsStringSync(), payload);

    await rust.sftpRemove(sessionId: id, path: remotePath, isDir: false);
    final entriesAfter = await rust.sftpList(sessionId: id, path: home);
    expect(entriesAfter.any((e) => e.name == '$marker.txt'), isFalse,
        reason: 'remove should delete the file');

    await rust.sftpClose(sessionId: id);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
