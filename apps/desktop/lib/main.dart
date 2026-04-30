// SPDX-License-Identifier: Apache-2.0
//
// Tindra desktop — Phase 1.1 interactive shell.
// Connect form on the left, live terminal on the right with line-buffered
// input. No VT/ANSI parsing yet — escape sequences will appear as raw
// characters until Phase 1.2 wires up `alacritty_terminal`.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tindra_desktop/src/rust/api/ssh.dart';
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
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();

  _ConnState _state = _ConnState.disconnected;
  BigInt? _sessionId;
  StreamSubscription<Uint8List>? _outputSub;
  String _output = '';
  String? _error;

  // UTF-8 streaming decoder (handles bytes split across chunks).
  final _decoder = const Utf8Decoder(allowMalformed: true);

  Future<void> _connect() async {
    setState(() {
      _state = _ConnState.connecting;
      _output = '';
      _error = null;
    });
    try {
      final id = await openShellPubkey(
        host: _host.text.trim(),
        port: int.parse(_port.text.trim()),
        username: _user.text.trim(),
        privateKeyPath: _keyPath.text.trim(),
        passphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
        cols: 120,
        rows: 32,
      );
      _sessionId = id;
      _outputSub = shellOutputStream(sessionId: id).listen(
        (bytes) {
          // Decode each chunk and append. Auto-scroll on next frame.
          final text = _decoder.convert(bytes);
          setState(() => _output += text);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              _scroll.animateTo(
                _scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 50),
                curve: Curves.easeOut,
              );
            }
          });
        },
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
      // Move keyboard focus into the terminal input.
      _inputFocus.requestFocus();
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
    await shellClose(sessionId: id);
    setState(() {
      _sessionId = null;
      _state = _ConnState.disconnected;
    });
  }

  Future<void> _sendLine() async {
    final id = _sessionId;
    if (id == null) return;
    final line = _input.text;
    _input.clear();
    final bytes = Uint8List.fromList(utf8.encode('$line\r'));
    try {
      await shellWrite(sessionId: id, data: bytes);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _sendCtrl(String key) async {
    final id = _sessionId;
    if (id == null) return;
    // Ctrl+key → ASCII control code (e.g. C=3, D=4, L=12, Z=26).
    final upper = key.toUpperCase().codeUnitAt(0);
    if (upper < 0x40 || upper > 0x5F) return;
    final code = upper - 0x40;
    await shellWrite(sessionId: id, data: Uint8List.fromList([code]));
  }

  @override
  void dispose() {
    _outputSub?.cancel();
    if (_sessionId != null) {
      shellClose(sessionId: _sessionId!);
    }
    for (final c in [_host, _port, _user, _keyPath, _passphrase, _input]) {
      c.dispose();
    }
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_state == _ConnState.connected
            ? 'Tindra · ${_user.text}@${_host.text}'
            : 'Tindra · Phase 1.1 — interactive shell'),
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
        color: const Color(0xFF0A0C12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: SelectableText(
                    _output.isEmpty && _state != _ConnState.connected
                        ? '(not connected)'
                        : _output,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xFFE3E9F1),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF1F2937)),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              const Text(
                '\$ ',
                style: TextStyle(
                  color: Color(0xFF7AC0FF),
                  fontFamily: 'Consolas',
                  fontSize: 13,
                ),
              ),
              Expanded(
                child: Shortcuts(
                  shortcuts: <ShortcutActivator, Intent>{
                    LogicalKeySet(LogicalKeyboardKey.control,
                        LogicalKeyboardKey.keyC): const _CtrlIntent('C'),
                    LogicalKeySet(LogicalKeyboardKey.control,
                        LogicalKeyboardKey.keyD): const _CtrlIntent('D'),
                    LogicalKeySet(LogicalKeyboardKey.control,
                        LogicalKeyboardKey.keyL): const _CtrlIntent('L'),
                  },
                  child: Actions(
                    actions: <Type, Action<Intent>>{
                      _CtrlIntent: CallbackAction<_CtrlIntent>(
                        onInvoke: (intent) {
                          _sendCtrl(intent.key);
                          return null;
                        },
                      ),
                    },
                    child: TextField(
                      controller: _input,
                      focusNode: _inputFocus,
                      enabled: _state == _ConnState.connected,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        filled: false,
                        isDense: true,
                        hintText: 'type a command, Enter to send · Ctrl+C/D/L',
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 13,
                        color: Color(0xFFE3E9F1),
                      ),
                      onSubmitted: (_) => _sendLine(),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CtrlIntent extends Intent {
  const _CtrlIntent(this.key);
  final String key;
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
