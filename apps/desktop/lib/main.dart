// SPDX-License-Identifier: Apache-2.0
//
// Tindra desktop — Phase 0 hello-world.
// Verifies the Flutter ↔ flutter_rust_bridge ↔ Rust (tindra-core) round-trip.
// Replace with the real shell/terminal UI in Phase 1.

import 'package:flutter/material.dart';
import 'package:tindra_desktop/src/rust/api/hello.dart';
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
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E1014),
      ),
      home: const HelloScreen(),
    );
  }
}

class HelloScreen extends StatelessWidget {
  const HelloScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final greeting = echo(msg: 'hello from Flutter');
    final version = coreVersion();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tindra · Phase 0'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Rust → Dart bridge OK',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            _Row(label: 'echo()', value: greeting),
            _Row(label: 'core_version()', value: 'tindra-core $version'),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Consolas',
                color: Color(0xFF8AA0B5),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'Consolas'),
            ),
          ),
        ],
      ),
    );
  }
}
