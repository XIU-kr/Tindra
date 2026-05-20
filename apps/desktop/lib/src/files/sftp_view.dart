part of '../../main.dart';

// ============================================================================
// Files (SFTP) view
// ============================================================================

class _FilesView extends StatefulWidget {
  const _FilesView({required this.profiles});
  final List<rust.Profile> profiles;
  @override
  State<_FilesView> createState() => _FilesViewState();
}

class _FilesViewState extends State<_FilesView> {
  String? _selProfileId;
  BigInt? _sessionId;
  String _remotePath = '';
  List<rust.SftpEntry> _remoteEntries = [];
  final TindraTransferQueue _transfers = TindraTransferQueue();
  final Queue<({String id, bool resume})> _pendingTransfers = Queue();
  final Set<String> _scheduledTransfers = <String>{};
  int _runningTransfers = 0;
  String? _error;
  bool _busy = false;

  static const int _maxConcurrentTransfers = 2;

  @override
  void initState() {
    super.initState();
    final ssh = widget.profiles.where((p) => p.transport == 'ssh').toList();
    if (ssh.isNotEmpty) {
      _selProfileId = ssh.first.id;
      _connect();
    }
  }

  @override
  void dispose() {
    final id = _sessionId;
    _sessionId = null;
    if (id != null) rust.sftpClose(sessionId: id);
    _pendingTransfers.clear();
    _scheduledTransfers.clear();
    _transfers.dispose();
    super.dispose();
  }

  rust.Profile? get _profile =>
      widget.profiles.where((p) => p.id == _selProfileId).firstOrNull;

  Future<void> _connect() async {
    final p = _profile;
    if (p == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final id = _sessionId;
      if (id != null) {
        await rust.sftpClose(sessionId: id);
      }
      final trusted = await _ensureTrustedProfileHostKey(p);
      if (!trusted) {
        _error = l10n.hostKeyNotTrusted;
        return;
      }
      final jump = rust.JumpHost(
        host: p.jumpHost,
        port: p.jumpPort == 0 ? 22 : p.jumpPort,
        username: p.jumpUsername,
        privateKeyPath: p.jumpPrivateKeyPath,
        passphrase: null,
      );
      final BigInt sid;
      if (p.authMethod == 'agent') {
        sid = await rust.openSftpAgent(
          host: p.host,
          port: p.port,
          username: p.username,
          jump: jump,
        );
      } else if (p.authMethod == 'password') {
        final password = await _promptPassword(p);
        if (password == null) {
          _error = l10n.passwordRequired;
          return;
        }
        sid = await rust.openSftpPassword(
          host: p.host,
          port: p.port,
          username: p.username,
          password: password,
          jump: jump,
        );
      } else if (p.authMethod == 'keyboard-interactive') {
        sid = await _openKeyboardInteractiveSftp(p, jump);
      } else {
        sid = await rust.openSftpPubkey(
          host: p.host,
          port: p.port,
          username: p.username,
          privateKeyPath: p.privateKeyPath,
          passphrase: null,
          jump: jump,
        );
      }
      _sessionId = sid;
      _remotePath = await rust.sftpHome(sessionId: sid);
      await _refresh();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _ensureTrustedProfileHostKey(rust.Profile profile) async {
    if (profile.jumpHost.isEmpty) {
      return _ensureTrustedHostKey(profile.host, profile.port);
    }
    final jumpPort = profile.jumpPort == 0 ? 22 : profile.jumpPort;
    final jumpTrusted = await _ensureTrustedHostKey(profile.jumpHost, jumpPort);
    if (!jumpTrusted) return false;
    return _ensureTrustedHostKey(
      profile.host,
      profile.port,
      viaJump: rust.JumpHost(
        host: profile.jumpHost,
        port: jumpPort,
        username: profile.jumpUsername,
        privateKeyPath: profile.jumpPrivateKeyPath,
        passphrase: null,
      ),
    );
  }

  Future<bool> _ensureTrustedHostKey(
    String host,
    int port, {
    rust.JumpHost? viaJump,
  }) async {
    final l10n = AppLocalizations.of(context);
    final check = viaJump == null
        ? await rust.probeHostKey(host: host, port: port)
        : await rust.probeHostKeyViaJump(host: host, port: port, jump: viaJump);
    if (!mounted) return false;
    if (check.status == 'trusted') return true;
    if (check.status == 'changed') {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.hostKeyChangedTitle),
          content: HostKeyDecisionDetails(
            host: host,
            port: port,
            status: 'changed',
            expected: check.expected,
            actual: check.actual,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
      return false;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.trustHostKeyTitle),
        content: HostKeyDecisionDetails(
          host: host,
          port: port,
          status: 'new',
          actual: check.actual,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.trust),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (approved == true) {
      await rust.trustHostKey(
        host: host,
        port: port,
        fingerprint: check.actual,
      );
      return true;
    }
    return false;
  }

  Future<String?> _promptPassword(rust.Profile profile) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.passwordFor(profile.name)),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.password),
            onSubmitted: (_) => Navigator.pop(context, controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(l10n.connect),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  String? _keyboardInteractivePromptFromError(String error) {
    const marker = 'keyboard-interactive prompt has no configured response: ';
    final idx = error.indexOf(marker);
    if (idx < 0) return null;
    return error.substring(idx + marker.length).trim();
  }

  Future<String?> _promptKeyboardInteractive(
    rust.Profile profile,
    String prompt,
  ) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppLocalizations.of(context).keyboardInteractive),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText:
                prompt.toLowerCase().contains('password') ||
                prompt.toLowerCase().contains('passcode') ||
                prompt.toLowerCase().contains('otp'),
            decoration: InputDecoration(
              labelText: prompt.isEmpty ? profile.name : prompt,
            ),
            onSubmitted: (_) => Navigator.pop(context, controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(AppLocalizations.of(context).connect),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<BigInt> _openKeyboardInteractiveSftp(
    rust.Profile profile,
    rust.JumpHost jump,
  ) async {
    final responses = <String>[];
    final passwordRequired = AppLocalizations.of(context).passwordRequired;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        return await rust.openSftpKeyboardInteractive(
          host: profile.host,
          port: profile.port,
          username: profile.username,
          responses: responses,
          jump: jump,
        );
      } catch (e) {
        final prompt = _keyboardInteractivePromptFromError(e.toString());
        if (prompt == null) rethrow;
        final answer = await _promptKeyboardInteractive(profile, prompt);
        if (answer == null) {
          throw passwordRequired;
        }
        responses.add(answer);
      }
    }
    throw 'Too many keyboard-interactive prompts.';
  }

  Future<void> _refresh() async {
    final id = _sessionId;
    if (id == null) return;
    try {
      final list = await rust.sftpList(sessionId: id, path: _remotePath);
      list.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      setState(() => _remoteEntries = list);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _navigate(rust.SftpEntry e) {
    if (!e.isDir) return;
    if (e.name == '..') {
      final idx = _remotePath.lastIndexOf('/');
      if (idx > 0) {
        _remotePath = _remotePath.substring(0, idx);
      } else if (idx == 0 && _remotePath.length > 1) {
        _remotePath = '/';
      }
    } else {
      _remotePath = _remotePath.endsWith('/')
          ? '$_remotePath${e.name}'
          : '$_remotePath/${e.name}';
    }
    _refresh();
  }

  Future<void> _download(rust.SftpEntry entry) async {
    final id = _sessionId;
    if (id == null || entry.isDir) return;
    final l10n = AppLocalizations.of(context);
    final downloads = Platform.environment['USERPROFILE'] == null
        ? Directory.current.path
        : '${Platform.environment['USERPROFILE']}\\Downloads';
    final localPath = '$downloads\\${entry.name}';
    final file = File(localPath);
    if (await file.exists()) {
      if (!mounted) return;
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.overwriteFileQuestion),
          content: Text(l10n.overwriteFileContent(localPath)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.overwrite),
            ),
          ],
        ),
      );
      if (overwrite != true) return;
    }
    final remotePath = _remotePath.endsWith('/')
        ? '$_remotePath${entry.name}'
        : '$_remotePath/${entry.name}';
    final item = TindraTransferItem(
      id: 'download-${DateTime.now().microsecondsSinceEpoch}',
      name: entry.name,
      direction: TindraTransferDirection.download,
      localPath: localPath,
      remotePath: remotePath,
      totalBytes: entry.size.toInt(),
    );
    _transfers.enqueue(item);
    _scheduleTransfer(item.id, resume: false);
  }

  void _scheduleTransfer(String transferId, {required bool resume}) {
    if (_scheduledTransfers.add(transferId)) {
      _pendingTransfers.add((id: transferId, resume: resume));
    }
    _pumpTransfers();
  }

  void _pumpTransfers() {
    while (_runningTransfers < _maxConcurrentTransfers &&
        _pendingTransfers.isNotEmpty) {
      final next = _pendingTransfers.removeFirst();
      final item = _transfers.items.where((it) => it.id == next.id).firstOrNull;
      if (item == null || item.status == TindraTransferStatus.canceled) {
        _scheduledTransfers.remove(next.id);
        continue;
      }
      _runningTransfers += 1;
      unawaited(_runScheduledTransfer(item, resume: next.resume));
    }
  }

  Future<void> _runScheduledTransfer(
    TindraTransferItem item, {
    required bool resume,
  }) async {
    try {
      if (item.direction == TindraTransferDirection.download) {
        await _runDownload(item.id, resume: resume);
      } else {
        await _runUpload(item.id);
      }
    } finally {
      _runningTransfers = _runningTransfers > 0 ? _runningTransfers - 1 : 0;
      _scheduledTransfers.remove(item.id);
      _pumpTransfers();
    }
  }

  Future<void> _runDownload(String transferId, {required bool resume}) async {
    final id = _sessionId;
    if (id == null) return;
    final item = _transfers.items
        .where((it) => it.id == transferId)
        .firstOrNull;
    if (item == null) return;
    _transfers.update(
      transferId,
      (it) =>
          it.copyWith(status: TindraTransferStatus.running, errorMessage: null),
    );
    try {
      await for (final progress in rust.sftpDownloadWithProgress(
        transferId: transferId,
        sessionId: id,
        remotePath: item.remotePath,
        localPath: item.localPath,
        resume: resume,
      )) {
        final latest = _transfers.items
            .where((it) => it.id == transferId)
            .firstOrNull;
        if (latest?.status == TindraTransferStatus.canceled) return;
        _transfers.update(
          transferId,
          (it) => it.copyWith(
            status: progress.done
                ? TindraTransferStatus.succeeded
                : TindraTransferStatus.running,
            bytesTransferred: progress.bytesTransferred.toInt(),
            totalBytes: progress.totalBytes.toInt() > 0
                ? progress.totalBytes.toInt()
                : it.totalBytes,
          ),
        );
      }
      final latest = _transfers.items
          .where((it) => it.id == transferId)
          .firstOrNull;
      if (latest == null || latest.status == TindraTransferStatus.canceled) {
        return;
      }
      _transfers.update(
        transferId,
        (it) => it.copyWith(
          status: TindraTransferStatus.succeeded,
          bytesTransferred: it.totalBytes ?? it.bytesTransferred,
        ),
      );
    } catch (e) {
      final latest = _transfers.items
          .where((it) => it.id == transferId)
          .firstOrNull;
      if (latest == null || latest.status == TindraTransferStatus.canceled) {
        return;
      }
      _transfers.update(
        transferId,
        (it) => it.copyWith(
          status: TindraTransferStatus.failed,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _promptUpload() async {
    final l10n = AppLocalizations.of(context);
    final local = TextEditingController();
    final remote = TextEditingController(
      text: _remotePath.endsWith('/') ? _remotePath : '$_remotePath/',
    );
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.upload),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: local,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.localPath),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remote,
                  decoration: InputDecoration(labelText: l10n.remotePath),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.upload),
            ),
          ],
        ),
      );
      if (ok == true) {
        await _upload(local.text.trim(), remote.text.trim());
      }
    } finally {
      local.dispose();
      remote.dispose();
    }
  }

  Future<void> _upload(String localPath, String remotePath) async {
    final id = _sessionId;
    if (id == null || localPath.isEmpty || remotePath.isEmpty) return;
    final file = File(localPath);
    if (!await file.exists()) {
      if (mounted) {
        setState(
          () => _error = AppLocalizations.of(
            context,
          ).localFileNotFound(localPath),
        );
      }
      return;
    }
    final name = localPath.split(RegExp(r'[\\/]')).last;
    final totalBytes = await file.length();
    final item = TindraTransferItem(
      id: 'upload-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      direction: TindraTransferDirection.upload,
      localPath: localPath,
      remotePath: remotePath,
      totalBytes: totalBytes,
    );
    _transfers.enqueue(item);
    _scheduleTransfer(item.id, resume: false);
  }

  Future<void> _runUpload(String transferId) async {
    final id = _sessionId;
    if (id == null) return;
    final item = _transfers.items
        .where((it) => it.id == transferId)
        .firstOrNull;
    if (item == null) return;
    _transfers.update(
      transferId,
      (it) =>
          it.copyWith(status: TindraTransferStatus.running, errorMessage: null),
    );
    try {
      await for (final progress in rust.sftpUploadWithProgress(
        transferId: transferId,
        sessionId: id,
        localPath: item.localPath,
        remotePath: item.remotePath,
      )) {
        final latest = _transfers.items
            .where((it) => it.id == transferId)
            .firstOrNull;
        if (latest?.status == TindraTransferStatus.canceled) return;
        _transfers.update(
          transferId,
          (it) => it.copyWith(
            status: progress.done
                ? TindraTransferStatus.succeeded
                : TindraTransferStatus.running,
            bytesTransferred: progress.bytesTransferred.toInt(),
            totalBytes: progress.totalBytes.toInt() > 0
                ? progress.totalBytes.toInt()
                : it.totalBytes,
          ),
        );
      }
      final latest = _transfers.items
          .where((it) => it.id == transferId)
          .firstOrNull;
      if (latest == null || latest.status == TindraTransferStatus.canceled) {
        return;
      }
      _transfers.update(
        transferId,
        (it) => it.copyWith(
          status: TindraTransferStatus.succeeded,
          bytesTransferred: it.totalBytes ?? it.bytesTransferred,
        ),
      );
      await _refresh();
    } catch (e) {
      final latest = _transfers.items
          .where((it) => it.id == transferId)
          .firstOrNull;
      if (latest == null || latest.status == TindraTransferStatus.canceled) {
        return;
      }
      _transfers.update(
        transferId,
        (it) => it.copyWith(
          status: TindraTransferStatus.failed,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _retryTransfer(TindraTransferItem item) {
    _transfers.markRetrying(item.id);
    _scheduleTransfer(
      item.id,
      resume: item.direction == TindraTransferDirection.download,
    );
  }

  Future<void> _cancelTransfer(String transferId) async {
    _pendingTransfers.removeWhere((entry) => entry.id == transferId);
    _scheduledTransfers.remove(transferId);
    _transfers.markCanceled(transferId);
    await rust.cancelSftpTransfer(transferId: transferId);
    _pumpTransfers();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final segs = _remotePath.split('/').where((s) => s.isNotEmpty).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ViewHead(
            eyebrow: l10n.filesSftpEyebrow,
            title: l10n.browseRemote,
            lede: l10n.filesSftpLede,
            actions: [
              _GhostButton(
                icon: Icons.file_upload_outlined,
                label: l10n.upload,
                onTap: _sessionId == null ? null : _promptUpload,
              ),
              if (widget.profiles.where((p) => p.transport == 'ssh').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _bg1,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButton<String>(
                    value: _selProfileId,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: _mono(size: 12, color: _ink0),
                    dropdownColor: _bg2,
                    items: widget.profiles
                        .where((p) => p.transport == 'ssh')
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _selProfileId = v);
                      _connect();
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _IconBtn(
                icon: Icons.arrow_upward,
                tooltip: l10n.up,
                onTap: () {
                  final entry = _remoteEntries.firstWhere(
                    (e) => e.name == '..',
                    orElse: () => rust.SftpEntry(
                      name: '..',
                      isDir: true,
                      isSymlink: false,
                      size: BigInt.zero,
                      mtime: BigInt.zero,
                      permissions: 0,
                    ),
                  );
                  _navigate(entry);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _bg1,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text('/', style: _mono(size: 12, color: _ink3)),
                      for (var i = 0; i < segs.length; i++) ...[
                        Text(segs[i], style: _mono(size: 12, color: _ink1)),
                        if (i < segs.length - 1)
                          Text('/', style: _mono(size: 12, color: _ink3)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.4,
                    color: _acc,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null) _errorBanner(_error!),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _filesTable()),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: _transfersPanel()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isLight ? const Color(0xFFFCEDE9) : const Color(0xFF2A1417),
        border: Border.all(color: _Pal.cRose.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: _Pal.cRose),
          const SizedBox(width: 8),
          Expanded(
            child: Text(e, style: _mono(size: 11.5, color: _Pal.cRose)),
          ),
          _IconBtn(
            icon: Icons.refresh,
            iconSize: 13,
            onTap: _busy ? null : _connect,
          ),
          const SizedBox(width: 4),
          _IconBtn(
            icon: Icons.close,
            iconSize: 13,
            onTap: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  Widget _filesTable() {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _bg1,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    l10n.tableName.toUpperCase(),
                    style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.5),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    l10n.tableSize.toUpperCase(),
                    textAlign: TextAlign.right,
                    style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 150,
                  child: Text(
                    l10n.tableModified.toUpperCase(),
                    textAlign: TextAlign.right,
                    style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          if (_sessionId == null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  widget.profiles.where((p) => p.transport == 'ssh').isEmpty
                      ? l10n.addSshProfileToBrowse
                      : l10n.connectingEllipsis,
                  style: _mono(size: 12, color: _ink2),
                ),
              ),
            )
          else
            for (var i = 0; i < _remoteEntries.length; i++)
              _SftpRow(
                entry: _remoteEntries[i],
                last: i == _remoteEntries.length - 1,
                onTap: () => _navigate(_remoteEntries[i]),
                onDownload: () => _download(_remoteEntries[i]),
              ),
        ],
      ),
    );
  }

  Widget _transfersPanel() {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _transfers,
      builder: (context, _) {
        final items = _transfers.items;
        final status = _transfers.activeCount > 0
            ? l10n.activeTransferCount(_transfers.activeCount)
            : _transfers.failedCount > 0
            ? l10n.failedTransferCount(_transfers.failedCount)
            : l10n.idle;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _bg1,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    l10n.transfers.toUpperCase(),
                    style: _mono(
                      size: 11,
                      color: _ink1,
                      letterSpacing: 1.6,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(status, style: _mono(size: 11, color: _ink3)),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: _line),
              const SizedBox(height: 14),
              if (items.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.cloud_done_outlined, size: 20, color: _ink3),
                      const SizedBox(height: 6),
                      Text(
                        l10n.noTransfersInFlight,
                        style: _mono(size: 11, color: _ink3),
                      ),
                    ],
                  ),
                )
              else
                for (final item in items)
                  _TransferRow(
                    item: item,
                    onRetry: () => _retryTransfer(item),
                    onCancel: () => unawaited(_cancelTransfer(item.id)),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.item,
    required this.onRetry,
    required this.onCancel,
  });

  final TindraTransferItem item;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final directionIcon = item.direction == TindraTransferDirection.download
        ? Icons.file_download_outlined
        : Icons.file_upload_outlined;
    final statusColor = item.status == TindraTransferStatus.failed
        ? _Pal.cRose
        : item.status == TindraTransferStatus.succeeded
        ? _Pal.cEmerald
        : _ink2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(directionIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.name,
                  overflow: TextOverflow.ellipsis,
                  style: _mono(size: 11.5, color: _ink1),
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  minHeight: 3,
                  value: item.progress,
                  backgroundColor: _line,
                  color: statusColor,
                ),
              ],
            ),
          ),
          if (item.canRetry)
            _IconBtn(
              icon: Icons.replay_outlined,
              tooltip: AppLocalizations.of(context).retry,
              onTap: onRetry,
              iconSize: 13,
            ),
          if (item.canCancel)
            _IconBtn(
              icon: Icons.close,
              tooltip: AppLocalizations.of(context).cancel,
              onTap: onCancel,
              iconSize: 13,
            ),
        ],
      ),
    );
  }
}

class _SftpRow extends StatefulWidget {
  const _SftpRow({
    required this.entry,
    required this.last,
    required this.onTap,
    required this.onDownload,
  });
  final rust.SftpEntry entry;
  final bool last;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  @override
  State<_SftpRow> createState() => _SftpRowState();
}

class _SftpRowState extends State<_SftpRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(
            color: _hover ? _bg2 : null,
            border: Border(
              bottom: BorderSide(
                color: widget.last ? Colors.transparent : _line,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: e.isDir ? _acc.withValues(alpha: 0.9) : _bg3,
                  border: e.isDir ? null : Border.all(color: _line2),
                  borderRadius: e.isDir
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(2),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        )
                      : BorderRadius.circular(2),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  e.name,
                  style: _mono(size: 12.5, color: e.isDir ? _accDeep : _ink0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  e.isDir ? '' : _fmtSize(e.size),
                  textAlign: TextAlign.right,
                  style: _mono(size: 12, color: _ink2),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 150,
                child: Text(
                  _fmtMtime(e.mtime),
                  textAlign: TextAlign.right,
                  style: _mono(size: 12, color: _ink2),
                ),
              ),
              SizedBox(
                width: 48,
                child: e.isDir
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.centerRight,
                        child: _IconBtn(
                          icon: Icons.file_download_outlined,
                          tooltip: AppLocalizations.of(context).download,
                          onTap: widget.onDownload,
                          iconSize: 13,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtSize(BigInt b) {
    final n = b.toInt();
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    if (n < 1024 * 1024 * 1024) {
      return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(n / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _fmtMtime(BigInt mt) {
    final l10n = AppLocalizations.of(context);
    final ms = mt.toInt();
    if (ms <= 0) return l10n.unknown;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms * 1000).toLocal();
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
