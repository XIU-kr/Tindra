import 'package:flutter_test/flutter_test.dart';
import 'package:tindra_shared_ui/tindra_shared_ui.dart';

void main() {
  test('assesses safe and risky terminal paste payloads', () {
    final singleLine = assessTerminalPaste('ls -la');
    expect(singleLine.risk, TerminalPasteRisk.normal);
    expect(singleLine.shouldConfirm, isFalse);

    final multiline = assessTerminalPaste('cd /tmp\nrm -rf build');
    expect(multiline.risk, TerminalPasteRisk.multiline);
    expect(multiline.shouldConfirm, isTrue);

    final large = assessTerminalPaste('x' * 4096);
    expect(large.risk, TerminalPasteRisk.large);
    expect(large.shouldConfirm, isTrue);
  });

  test('copies selected terminal text before falling back to screen text', () {
    expect(
      chooseTerminalCopyText(selectionText: 'selected', screenText: 'screen'),
      'selected',
    );
    expect(
      chooseTerminalCopyText(selectionText: '', screenText: 'screen'),
      'screen',
    );
    expect(chooseTerminalCopyText(), isNull);
  });

  test('tracks transfer queue state and progress', () {
    final queue = TindraTransferQueue();
    queue.enqueue(
      const TindraTransferItem(
        id: '1',
        name: 'archive.tar',
        direction: TindraTransferDirection.download,
        localPath: r'C:\Downloads\archive.tar',
        remotePath: '/tmp/archive.tar',
        totalBytes: 100,
      ),
    );

    expect(queue.activeCount, 1);
    expect(queue.items.single.progress, 0);

    queue.update(
      '1',
      (item) => item.copyWith(
        status: TindraTransferStatus.running,
        bytesTransferred: 25,
      ),
    );
    expect(queue.items.single.progress, 0.25);

    queue.markCanceled('1');
    expect(queue.items.single.status, TindraTransferStatus.canceled);

    queue.removeFinished();
    expect(queue.items, isEmpty);
  });

  test('finds terminal text matches with line and column offsets', () {
    final matches = findTerminalTextMatches('alpha\nBeta\nbeta', 'beta');

    expect(matches, hasLength(2));
    expect(matches[0].line, 1);
    expect(matches[0].column, 0);
    expect(matches[1].line, 2);
    expect(matches[1].column, 0);
  });

  test('can restrict terminal search to whole words', () {
    final matches = findTerminalTextMatches(
      'cat scatter cat_1 cat',
      'cat',
      wholeWord: true,
    );

    expect(matches, hasLength(2));
    expect(matches[0].start, 0);
    expect(matches[1].start, 18);
  });

  test('can search terminal text with regex patterns', () {
    final matches = findTerminalTextMatches(
      'err-1 ok err-42',
      r'err-\d+',
      regex: true,
    );

    expect(matches, hasLength(2));
    expect(matches[0].start, 0);
    expect(matches[1].start, 9);
  });

  test('regex terminal search handles invalid patterns safely', () {
    final matches = findTerminalTextMatches('anything', r'(', regex: true);

    expect(matches, isEmpty);
    expect(
      buildTerminalSearchState('anything', r'(', regex: true).invalidPattern,
      isTrue,
    );
  });

  test('regex terminal search respects case and whole-word options', () {
    final matches = findTerminalTextMatches(
      'ERR-1 err-2 err-20x',
      r'err-\d+',
      regex: true,
      caseSensitive: true,
      wholeWord: true,
    );

    expect(matches, hasLength(1));
    expect(matches.single.start, 6);
  });

  test('builds terminal search state with a display index', () {
    final state = buildTerminalSearchState(
      'one two one',
      'one',
      currentIndex: 4,
    );

    expect(state.count, 2);
    expect(state.currentIndex, 1);
    expect(state.displayIndex, 2);
    expect(state.currentMatch?.start, 8);
  });

  test('can requeue failed transfers for retry', () {
    final queue = TindraTransferQueue();
    queue.enqueue(
      const TindraTransferItem(
        id: 'failed',
        name: 'backup.sql',
        direction: TindraTransferDirection.upload,
        localPath: r'C:\backup.sql',
        remotePath: '/backup.sql',
        status: TindraTransferStatus.failed,
        bytesTransferred: 42,
        totalBytes: 100,
        errorMessage: 'network closed',
      ),
    );

    queue.markRetrying('failed');

    expect(queue.items.single.status, TindraTransferStatus.queued);
    expect(queue.items.single.bytesTransferred, 0);
    expect(queue.items.single.errorMessage, isNull);
  });

  test('keeps profile and session view models platform neutral', () {
    const profile = TindraProfileViewModel(
      id: 'p1',
      name: 'prod',
      host: 'example.com',
      port: 22,
      username: 'xiu',
      authMethod: TindraAuthMethod.password,
      jumpHost: 'jump.example.com',
    );
    const session = TindraSessionViewModel(
      id: 's1',
      profileName: 'prod',
      state: TindraSessionVisualState.connected,
    );

    expect(profile.endpoint, 'xiu@example.com:22');
    expect(profile.usesJumpHost, isTrue);
    expect(
      TindraAuthMethod.values,
      contains(TindraAuthMethod.keyboardInteractive),
    );
    expect(session.canPaste, isTrue);
    expect(session.canReconnect, isFalse);
  });
}
