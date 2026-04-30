// SPDX-License-Identifier: Apache-2.0
//
// Tindra desktop — Phase 1.0 SSH demo.
// Single-shot SSH connect + remote command. No real terminal yet — that lands
// in Phase 1.1 with PTY + VT parser + grid renderer.

import 'package:flutter/material.dart';
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
      home: const ConnectScreen(),
    );
  }
}

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _host = TextEditingController(text: 'localhost');
  final _port = TextEditingController(text: '22');
  final _user = TextEditingController(text: 'XIU');
  final _keyPath = TextEditingController(
      text: r'C:\Users\XIU\.ssh\id_ed25519');
  final _passphrase = TextEditingController();
  final _command = TextEditingController(text: 'hostname & whoami & cd');

  bool _running = false;
  CommandOutput? _result;
  String? _error;
  Duration? _elapsed;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _result = null;
      _error = null;
      _elapsed = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final out = await runCommandPubkey(
        host: _host.text.trim(),
        port: int.parse(_port.text.trim()),
        username: _user.text.trim(),
        privateKeyPath: _keyPath.text.trim(),
        passphrase:
            _passphrase.text.isEmpty ? null : _passphrase.text,
        command: _command.text,
      );
      stopwatch.stop();
      setState(() {
        _result = out;
        _elapsed = stopwatch.elapsed;
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _error = e.toString();
        _elapsed = stopwatch.elapsed;
      });
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_host, _port, _user, _keyPath, _passphrase, _command]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tindra · Phase 1.0 — SSH exec'),
        backgroundColor: const Color(0xFF161A22),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left pane: form
            SizedBox(
              width: 380,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Field(label: 'Host', controller: _host),
                  Row(children: [
                    Expanded(
                      child: _Field(label: 'User', controller: _user),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: _Field(label: 'Port', controller: _port),
                    ),
                  ]),
                  _Field(label: 'Private key path', controller: _keyPath),
                  _Field(
                    label: 'Passphrase (optional)',
                    controller: _passphrase,
                    obscure: true,
                  ),
                  _Field(
                    label: 'Command',
                    controller: _command,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _running ? null : _run,
                    icon: _running
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_running ? 'Connecting…' : 'Run'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 32),
            // Right pane: output
            Expanded(child: _OutputPane(
              result: _result,
              error: _error,
              elapsed: _elapsed,
            )),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.maxLines = 1,
  });
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final int maxLines;

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
            maxLines: maxLines,
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _OutputPane extends StatelessWidget {
  const _OutputPane({
    required this.result,
    required this.error,
    required this.elapsed,
  });
  final CommandOutput? result;
  final String? error;
  final Duration? elapsed;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return _Block(
        title: 'Error',
        titleColor: const Color(0xFFFF6E6E),
        body: error!,
        elapsed: elapsed,
      );
    }
    if (result == null) {
      return Center(
        child: Text(
          'Fill the form and click Run.\n'
          'A successful result fills stdout · stderr · exit code panes here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    final r = result!;
    final exitColor = r.exitCode == 0
        ? const Color(0xFF4ADE80)
        : const Color(0xFFFF6E6E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            const Text('exit code: ',
                style: TextStyle(color: Color(0xFF8AA0B5))),
            Text('${r.exitCode}',
                style: TextStyle(
                  color: exitColor,
                  fontFamily: 'Consolas',
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(width: 16),
            if (elapsed != null)
              Text(
                '${elapsed!.inMilliseconds} ms',
                style: const TextStyle(
                  color: Color(0xFF8AA0B5),
                  fontFamily: 'Consolas',
                ),
              ),
          ]),
        ),
        if (r.stdout.isNotEmpty)
          Expanded(
            child: _Block(
              title: 'stdout',
              titleColor: const Color(0xFF7AC0FF),
              body: r.stdout,
            ),
          ),
        if (r.stderr.isNotEmpty) ...[
          const SizedBox(height: 8),
          Expanded(
            child: _Block(
              title: 'stderr',
              titleColor: const Color(0xFFFFB86C),
              body: r.stderr,
            ),
          ),
        ],
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.title,
    required this.titleColor,
    required this.body,
    this.elapsed,
  });
  final String title;
  final Color titleColor;
  final String body;
  final Duration? elapsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontFamily: 'Consolas',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                body,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
