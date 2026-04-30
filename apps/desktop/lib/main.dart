// SPDX-License-Identifier: Apache-2.0
//
// Tindra desktop — Phase 1.3 colored, raw-keystroke, auto-resizing terminal.
// The Rust side feeds raw SSH output through a vt100 Parser and emits per-cell
// snapshots (text + fg/bg/attrs). The UI renders those cells as a coalesced
// Text.rich grid, captures every keystroke as raw bytes, and tracks the
// terminal pane's dimensions to push shell_resize on window changes.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _host = TextEditingController(text: 'localhost');
  final _port = TextEditingController(text: '22');
  final _user = TextEditingController(text: 'XIU');
  final _keyPath =
      TextEditingController(text: r'C:\Users\XIU\.ssh\id_ed25519');
  final _passphrase = TextEditingController();
  final _termFocus = FocusNode(debugLabel: 'terminal');

  _ConnState _state = _ConnState.disconnected;
  BigInt? _sessionId;
  StreamSubscription<rust.TerminalSnapshot>? _outputSub;
  rust.TerminalSnapshot? _snapshot;
  String? _error;

  // Geometry tracking. _cols/_rows is the size last reported to the remote PTY.
  int _cols = 120;
  int _rows = 32;
  Timer? _resizeDebounce;

  Future<void> _connect() async {
    setState(() {
      _state = _ConnState.connecting;
      _snapshot = null;
      _error = null;
    });
    try {
      final id = await rust.openShellPubkey(
        host: _host.text.trim(),
        port: int.parse(_port.text.trim()),
        username: _user.text.trim(),
        privateKeyPath: _keyPath.text.trim(),
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
      _termFocus.requestFocus();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _state = _ConnState.disconnected;
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
  /// Returns null if the event isn't ours to handle.
  List<int>? _keyEventToBytes(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final logical = event.logicalKey;

    // Named keys with canonical xterm sequences.
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

    // Ctrl+letter → ASCII control code (Ctrl+A=1, ..., Ctrl+Z=26).
    if (ctrl) {
      final ch = event.character;
      if (ch != null && ch.isNotEmpty) {
        final code = ch.toUpperCase().codeUnitAt(0);
        if (code >= 0x40 && code <= 0x5F) {
          return [code - 0x40];
        }
      }
    }

    // Alt+char → ESC + char.
    if (alt) {
      final ch = event.character;
      if (ch != null && ch.isNotEmpty) {
        return [0x1b, ...utf8.encode(ch)];
      }
    }

    // Plain printable character (already accounts for Shift).
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

  /// Schedule a resize push to the remote PTY when the visible grid changes.
  /// Debounced so dragging the window doesn't spam the server.
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
    for (final c in [_host, _port, _user, _keyPath, _passphrase]) {
      c.dispose();
    }
    _termFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_state == _ConnState.connected
            ? 'Tindra · ${_user.text}@${_host.text}'
            : 'Tindra · Phase 1.3'),
        backgroundColor: const Color(0xFF161A22),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 320, child: _connectionPanel()),
            const SizedBox(width: 12),
            Expanded(child: _terminalPanel()),
          ],
        ),
      ),
    );
  }

  Widget _connectionPanel() {
    final disabled = _state != _ConnState.disconnected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(label: 'Host', controller: _host, enabled: !disabled),
        Row(children: [
          Expanded(
              child: _Field(
                  label: 'User', controller: _user, enabled: !disabled)),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child:
                _Field(label: 'Port', controller: _port, enabled: !disabled),
          ),
        ]),
        _Field(
          label: 'Private key path',
          controller: _keyPath,
          enabled: !disabled,
        ),
        _Field(
          label: 'Passphrase (optional)',
          controller: _passphrase,
          enabled: !disabled,
          obscure: true,
        ),
        const SizedBox(height: 8),
        if (_state == _ConnState.disconnected)
          FilledButton.icon(
            onPressed: _connect,
            icon: const Icon(Icons.link),
            label: const Text('Connect'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )
        else if (_state == _ConnState.connecting)
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
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off),
            label: const Text('Disconnect'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B2C2C),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        const SizedBox(height: 12),
        if (_snapshot != null)
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
        const SizedBox(height: 12),
        if (_error != null)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A1417),
              border: Border.all(color: const Color(0xFFFF6E6E)),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(10),
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFFFB4B4),
                fontFamily: 'Consolas',
                fontSize: 12,
              ),
            ),
          ),
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
                    isConnected: _state == _ConnState.connected,
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

/// Renders a TerminalSnapshot as a coalesced Text.rich grid plus a cursor
/// overlay. Adjacent cells with identical fg/bg/attrs are merged into a
/// single TextSpan so the widget tree stays small (typically a few dozen
/// spans even on busy screens).
class _CellGrid extends StatelessWidget {
  const _CellGrid({
    required this.snapshot,
    required this.isConnected,
    required this.isFocused,
    required this.charWidth,
    required this.lineHeight,
  });

  final rust.TerminalSnapshot? snapshot;
  final bool isConnected;
  final bool isFocused;
  final double charWidth;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    if (snapshot == null) {
      return Center(
        child: Text(
          isConnected ? 'waiting for first chunk…' : '(not connected)',
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
        if (cell.ch.isEmpty) continue; // wide-character continuation cell
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.enabled = true,
  });
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8AA0B5),
              ),
            ),
          ),
          TextField(
            controller: controller,
            obscureText: obscure,
            enabled: enabled,
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
          ),
        ],
      ),
    );
  }
}
