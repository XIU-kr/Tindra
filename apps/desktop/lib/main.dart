// SPDX-License-Identifier: Apache-2.0
//
// Tindra desktop — Phase 2 with profile manager.
// Saved connection profiles live in <data_dir>/Tindra/profiles.json. The
// left panel shows the profile list; the right panel is the terminal view
// from Phase 1.3 (cell grid + raw keystrokes + auto-resize).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tindra_desktop/src/rust/api/profiles.dart' as rust;
import 'package:tindra_desktop/src/rust/api/ssh.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const TindraApp());
}

class TindraApp extends StatelessWidget {
  const TindraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tindra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E1014),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7AC0FF),
          surface: Color(0xFF161A22),
          onSurface: Color(0xFFE3E9F1),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B2030),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      home: const ShellScreen(),
    );
  }
}

const Color _termFg = Color(0xFFE3E9F1);
const Color _termBg = Color(0xFF0A0C12);
const TextStyle _termStyle = TextStyle(
  fontFamily: 'Consolas',
  fontSize: 13,
  height: 1.35,
  color: _termFg,
);

enum _ConnState { disconnected, connecting, connected }

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final _passphrase = TextEditingController();
  final _termFocus = FocusNode(debugLabel: 'terminal');

  // Profile state
  List<rust.Profile> _profiles = [];
  String? _selectedId;
  bool _profilesLoading = true;

  // Connection state
  _ConnState _state = _ConnState.disconnected;
  BigInt? _sessionId;
  String? _activeProfileName; // for AppBar display while connected
  StreamSubscription<rust.TerminalSnapshot>? _outputSub;
  rust.TerminalSnapshot? _snapshot;
  String? _error;

  // Geometry tracking (cols/rows last reported to remote PTY).
  int _cols = 120;
  int _rows = 32;
  Timer? _resizeDebounce;

  rust.Profile? get _selected =>
      _profiles.where((p) => p.id == _selectedId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _refreshProfiles();
  }

  Future<void> _refreshProfiles() async {
    try {
      final list = await rust.listProfiles();
      setState(() {
        _profiles = list;
        _profilesLoading = false;
        if (_selectedId == null && list.isNotEmpty) {
          _selectedId = list.first.id;
        }
      });
    } catch (e) {
      setState(() {
        _profilesLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openProfileDialog({rust.Profile? existing}) async {
    final result = await showDialog<rust.Profile>(
      context: context,
      builder: (_) => _ProfileDialog(initial: existing),
    );
    if (result == null) return;
    try {
      final saved = await rust.upsertProfile(profile: result);
      await _refreshProfiles();
      setState(() => _selectedId = saved.id);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _deleteProfile(rust.Profile profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text('Permanently remove "${profile.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B2C2C),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await rust.deleteProfile(id: profile.id);
      await _refreshProfiles();
      setState(() {
        if (_selectedId == profile.id) {
          _selectedId = _profiles.isEmpty ? null : _profiles.first.id;
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _connect() async {
    final p = _selected;
    if (p == null) return;
    setState(() {
      _state = _ConnState.connecting;
      _snapshot = null;
      _error = null;
      _activeProfileName = p.name;
    });
    try {
      final id = await rust.openShellPubkey(
        host: p.host,
        port: p.port,
        username: p.username,
        privateKeyPath: p.privateKeyPath,
        passphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
        cols: _cols,
        rows: _rows,
      );
      _sessionId = id;
      _outputSub = rust.shellOutputStream(sessionId: id).listen(
        (snap) => setState(() => _snapshot = snap),
        onError: (e) {
          setState(() {
            _error = e.toString();
            _state = _ConnState.disconnected;
          });
        },
        onDone: () {
          setState(() => _state = _ConnState.disconnected);
        },
      );
      setState(() => _state = _ConnState.connected);
      _passphrase.clear();
      _termFocus.requestFocus();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _state = _ConnState.disconnected;
        _activeProfileName = null;
      });
    }
  }

  Future<void> _disconnect() async {
    final id = _sessionId;
    if (id == null) return;
    await _outputSub?.cancel();
    _outputSub = null;
    await rust.shellClose(sessionId: id);
    setState(() {
      _sessionId = null;
      _state = _ConnState.disconnected;
      _activeProfileName = null;
    });
  }

  Future<void> _writeBytes(List<int> bytes) async {
    final id = _sessionId;
    if (id == null) return;
    try {
      await rust.shellWrite(sessionId: id, data: bytes);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  /// Convert a Flutter key event to the byte sequence a Unix-like PTY expects.
  List<int>? _keyEventToBytes(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final logical = event.logicalKey;

    String? esc;
    if (logical == LogicalKeyboardKey.arrowUp) {
      esc = '\x1b[A';
    } else if (logical == LogicalKeyboardKey.arrowDown) {
      esc = '\x1b[B';
    } else if (logical == LogicalKeyboardKey.arrowRight) {
      esc = '\x1b[C';
    } else if (logical == LogicalKeyboardKey.arrowLeft) {
      esc = '\x1b[D';
    } else if (logical == LogicalKeyboardKey.home) {
      esc = '\x1b[H';
    } else if (logical == LogicalKeyboardKey.end) {
      esc = '\x1b[F';
    } else if (logical == LogicalKeyboardKey.pageUp) {
      esc = '\x1b[5~';
    } else if (logical == LogicalKeyboardKey.pageDown) {
      esc = '\x1b[6~';
    } else if (logical == LogicalKeyboardKey.delete) {
      esc = '\x1b[3~';
    } else if (logical == LogicalKeyboardKey.insert) {
      esc = '\x1b[2~';
    } else if (logical == LogicalKeyboardKey.escape) {
      esc = '\x1b';
    } else if (logical == LogicalKeyboardKey.backspace) {
      esc = '\x7f';
    } else if (logical == LogicalKeyboardKey.tab) {
      esc = '\t';
    } else if (logical == LogicalKeyboardKey.enter) {
      esc = '\r';
    } else if (logical == LogicalKeyboardKey.f1) {
      esc = '\x1bOP';
    } else if (logical == LogicalKeyboardKey.f2) {
      esc = '\x1bOQ';
    } else if (logical == LogicalKeyboardKey.f3) {
      esc = '\x1bOR';
    } else if (logical == LogicalKeyboardKey.f4) {
      esc = '\x1bOS';
    } else if (logical == LogicalKeyboardKey.f5) {
      esc = '\x1b[15~';
    } else if (logical == LogicalKeyboardKey.f6) {
      esc = '\x1b[17~';
    } else if (logical == LogicalKeyboardKey.f7) {
      esc = '\x1b[18~';
    } else if (logical == LogicalKeyboardKey.f8) {
      esc = '\x1b[19~';
    } else if (logical == LogicalKeyboardKey.f9) {
      esc = '\x1b[20~';
    } else if (logical == LogicalKeyboardKey.f10) {
      esc = '\x1b[21~';
    } else if (logical == LogicalKeyboardKey.f11) {
      esc = '\x1b[23~';
    } else if (logical == LogicalKeyboardKey.f12) {
      esc = '\x1b[24~';
    }
    if (esc != null) return utf8.encode(esc);

    if (ctrl) {
      final ch = event.character;
      if (ch != null && ch.isNotEmpty) {
        final code = ch.toUpperCase().codeUnitAt(0);
        if (code >= 0x40 && code <= 0x5F) {
          return [code - 0x40];
        }
      }
    }
    if (alt) {
      final ch = event.character;
      if (ch != null && ch.isNotEmpty) {
        return [0x1b, ...utf8.encode(ch)];
      }
    }
    final ch = event.character;
    if (ch != null && ch.isNotEmpty) {
      return utf8.encode(ch);
    }
    return null;
  }

  KeyEventResult _onTermKey(FocusNode node, KeyEvent event) {
    if (_state != _ConnState.connected) return KeyEventResult.ignored;
    final bytes = _keyEventToBytes(event);
    if (bytes != null) {
      _writeBytes(bytes);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scheduleResize(int cols, int rows) {
    if (cols == _cols && rows == _rows) return;
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 200), () {
      final id = _sessionId;
      if (id == null || _state != _ConnState.connected) return;
      _cols = cols;
      _rows = rows;
      rust.shellResize(sessionId: id, cols: cols, rows: rows);
    });
  }

  @override
  void dispose() {
    _resizeDebounce?.cancel();
    _outputSub?.cancel();
    if (_sessionId != null) {
      rust.shellClose(sessionId: _sessionId!);
    }
    _passphrase.dispose();
    _termFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_state == _ConnState.connected
            ? 'Tindra · ${_activeProfileName ?? "session"}'
            : 'Tindra'),
        backgroundColor: const Color(0xFF161A22),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 280, child: _sidePanel()),
            const SizedBox(width: 12),
            Expanded(child: _terminalPanel()),
          ],
        ),
      ),
    );
  }

  Widget _sidePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Profiles',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8AA0B5),
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              tooltip: 'New profile',
              onPressed: _state == _ConnState.disconnected
                  ? () => _openProfileDialog()
                  : null,
            ),
          ],
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161A22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: _profilesLoading
                ? const Center(
                    child:
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _profiles.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _profiles.length,
                        itemBuilder: (_, i) =>
                            _profileTile(_profiles[i]),
                      ),
          ),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 10),
          _connectionActions(_selected!),
        ],
        const SizedBox(height: 10),
        if (_snapshot != null && _state == _ConnState.connected)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'grid: ${_snapshot!.cols}×${_snapshot!.rows}    '
              'cursor: (${_snapshot!.cursorRow},${_snapshot!.cursorCol})',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8AA0B5),
                fontFamily: 'Consolas',
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A1417),
              border: Border.all(color: const Color(0xFFFF6E6E)),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFFB4B4),
                    fontFamily: 'Consolas',
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _error = null),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.dns_outlined,
                size: 36, color: Color(0xFF8AA0B5)),
            const SizedBox(height: 8),
            const Text(
              'No profiles yet',
              style: TextStyle(color: Color(0xFF8AA0B5)),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => _openProfileDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create one'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileTile(rust.Profile p) {
    final selected = p.id == _selectedId;
    return InkWell(
      onTap: _state == _ConnState.disconnected
          ? () => setState(() => _selectedId = p.id)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B2030) : null,
          border: Border(
            left: BorderSide(
              color: selected
                  ? const Color(0xFF7AC0FF)
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.name.isEmpty ? '(unnamed)' : p.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${p.username}@${p.host}${p.port == 22 ? "" : ":${p.port}"}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8AA0B5),
                fontFamily: 'Consolas',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectionActions(rust.Profile p) {
    if (_state == _ConnState.connected) {
      return FilledButton.icon(
        onPressed: _disconnect,
        icon: const Icon(Icons.link_off),
        label: const Text('Disconnect'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF8B2C2C),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _passphrase,
              obscureText: true,
              enabled: _state == _ConnState.disconnected,
              decoration: const InputDecoration(
                hintText: 'Key passphrase (if any)',
                hintStyle: TextStyle(fontSize: 12),
              ),
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        if (_state == _ConnState.connecting)
          FilledButton.icon(
            onPressed: null,
            icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            label: const Text('Connecting…'),
          )
        else
          FilledButton.icon(
            onPressed: _connect,
            icon: const Icon(Icons.link),
            label: Text('Connect to ${p.name}'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openProfileDialog(existing: p),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit'),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _deleteProfile(p),
          ),
        ]),
      ],
    );
  }

  Widget _terminalPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _termBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Focus(
          focusNode: _termFocus,
          autofocus: false,
          onKeyEvent: _onTermKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _termFocus.requestFocus(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final probe = TextPainter(
                  text: const TextSpan(text: 'M', style: _termStyle),
                  textDirection: TextDirection.ltr,
                )..layout();
                final charWidth = probe.width;
                final lineHeight = probe.height;
                probe.dispose();

                const padding = 12.0;
                final availW = constraints.maxWidth - padding * 2;
                final availH = constraints.maxHeight - padding * 2;
                final fitCols = (availW / charWidth).floor().clamp(20, 400);
                final fitRows = (availH / lineHeight).floor().clamp(8, 200);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scheduleResize(fitCols, fitRows);
                });

                return Padding(
                  padding: const EdgeInsets.all(padding),
                  child: _CellGrid(
                    snapshot: _snapshot,
                    state: _state,
                    isFocused: _termFocus.hasFocus,
                    charWidth: charWidth,
                    lineHeight: lineHeight,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CellGrid extends StatelessWidget {
  const _CellGrid({
    required this.snapshot,
    required this.state,
    required this.isFocused,
    required this.charWidth,
    required this.lineHeight,
  });

  final rust.TerminalSnapshot? snapshot;
  final _ConnState state;
  final bool isFocused;
  final double charWidth;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    if (snapshot == null) {
      return Center(
        child: Text(
          state == _ConnState.connected
              ? 'waiting for first chunk…'
              : state == _ConnState.connecting
                  ? 'connecting…'
                  : 'Pick a profile on the left, then Connect.',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    final s = snapshot!;
    final spans = _buildSpans(s);

    return Stack(
      children: [
        Positioned.fill(
          child: Text.rich(
            TextSpan(children: spans),
            softWrap: false,
            style: _termStyle,
          ),
        ),
        if (s.cursorVisible)
          Positioned(
            left: s.cursorCol * charWidth,
            top: s.cursorRow * lineHeight,
            width: charWidth,
            height: lineHeight,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: isFocused
                      ? const Color(0xFF7AC0FF).withValues(alpha: 0.55)
                      : const Color(0xFF7AC0FF).withValues(alpha: 0.20),
                  border: isFocused
                      ? null
                      : Border.all(
                          color: const Color(0xFF7AC0FF).withValues(alpha: 0.6),
                          width: 1,
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<TextSpan> _buildSpans(rust.TerminalSnapshot s) {
    final spans = <TextSpan>[];
    StringBuffer? buf;
    TextStyle? curStyle;

    void flush() {
      if (buf != null && buf!.isNotEmpty) {
        spans.add(TextSpan(text: buf!.toString(), style: curStyle));
      }
      buf = null;
      curStyle = null;
    }

    final cols = s.cols;
    final rows = s.rows;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final idx = row * cols + col;
        if (idx >= s.cells.length) break;
        final cell = s.cells[idx];
        if (cell.ch.isEmpty) continue;
        final style = _styleForCell(cell);
        if (style != curStyle) {
          flush();
          curStyle = style;
          buf = StringBuffer();
        }
        buf!.write(cell.ch);
      }
      flush();
      if (row + 1 < rows) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    flush();
    return spans;
  }
}

TextStyle _styleForCell(rust.Cell c) {
  final inverse = (c.attrs & 8) != 0;
  Color fg = c.fg.default_ ? _termFg : Color.fromARGB(255, c.fg.r, c.fg.g, c.fg.b);
  Color? bg = c.bg.default_ ? null : Color.fromARGB(255, c.bg.r, c.bg.g, c.bg.b);
  if (inverse) {
    final tmpFg = fg;
    fg = bg ?? _termBg;
    bg = tmpFg;
  }
  return TextStyle(
    color: fg,
    backgroundColor: bg,
    fontWeight: (c.attrs & 1) != 0 ? FontWeight.bold : null,
    fontStyle: (c.attrs & 2) != 0 ? FontStyle.italic : null,
    decoration: (c.attrs & 4) != 0 ? TextDecoration.underline : null,
    inherit: true,
    fontFamily: 'Consolas',
    fontSize: 13,
    height: 1.35,
  );
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({this.initial});
  final rust.Profile? initial;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _key;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _host = TextEditingController(text: p?.host ?? '');
    _port = TextEditingController(text: (p?.port ?? 22).toString());
    _user = TextEditingController(text: p?.username ?? '');
    _key = TextEditingController(
        text: p?.privateKeyPath ?? r'C:\Users\XIU\.ssh\id_ed25519');
    _notes = TextEditingController(text: p?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _user, _key, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final port = int.tryParse(_port.text.trim()) ?? 22;
    final p = rust.Profile(
      id: widget.initial?.id ?? '',
      name: _name.text.trim().isEmpty
          ? '${_user.text.trim()}@${_host.text.trim()}'
          : _name.text.trim(),
      host: _host.text.trim(),
      port: port,
      username: _user.text.trim(),
      privateKeyPath: _key.text.trim(),
      notes: _notes.text,
    );
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    return AlertDialog(
      backgroundColor: const Color(0xFF161A22),
      title: Text(isNew ? 'New profile' : 'Edit profile'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('Name', _name, hint: 'e.g. prod-web-1'),
              _row('Host', _host, hint: 'localhost / 1.2.3.4 / dev.example.com'),
              Row(children: [
                Expanded(child: _row('User', _user, hint: 'XIU')),
                const SizedBox(width: 8),
                SizedBox(width: 100, child: _row('Port', _port)),
              ]),
              _row('Private key path', _key),
              _row('Notes', _notes, hint: 'optional', maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _host.text.trim().isEmpty || _user.text.trim().isEmpty
              ? null
              : _save,
          child: Text(isNew ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Widget _row(String label, TextEditingController c,
      {String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8AA0B5)),
            ),
          ),
          TextField(
            controller: c,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: hint),
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
