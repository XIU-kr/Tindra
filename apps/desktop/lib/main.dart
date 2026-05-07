// SPDX-License-Identifier: Apache-2.0
//
// Tindra desktop — editorial-tech UI.
//
// Single-file Flutter shell that mirrors the Tindra Redesign prototype:
// 36px title bar with traffic lights, 230px sidebar with six top-level views,
// command palette (Cmd/Ctrl+K), and inline pages for Sessions, Profiles,
// Files (SFTP), Forwards, Host keys and Settings. All Rust FFI session
// management lives unchanged inside `_ShellScreenState` — only the
// presentation layer was rewritten.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:tindra_desktop/l10n/app_localizations.dart';
import 'package:tindra_desktop/src/rust/api/forward.dart' as rust;
import 'package:tindra_desktop/src/rust/api/profiles.dart' as rust;
import 'package:tindra_desktop/src/rust/api/settings.dart' as rust;
import 'package:tindra_desktop/src/rust/api/sftp.dart' as rust;
import 'package:tindra_desktop/src/rust/api/ssh.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

// ============================================================================
// Startup
// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();
  GoogleFonts.config.allowRuntimeFetching = true;
  await RustLib.init();
  try {
    appSettings.value = await rust.loadSettings();
  } catch (_) {
    // fall back to in-code defaults
  }
  await _registerQuakeHotkey();
  appSettings.addListener(_registerQuakeHotkey);
  runApp(const TindraApp());
}

Future<void> _registerQuakeHotkey() async {
  try {
    await hotKeyManager.unregisterAll();
  } catch (_) {}
  final raw = appSettings.value.quakeHotkey.trim();
  if (raw.isEmpty) return;
  final key = _parseHotkey(raw);
  if (key == null) return;
  try {
    await hotKeyManager.register(
      HotKey(key: key, scope: HotKeyScope.system),
      keyDownHandler: (_) async {
        try {
          final visible = await windowManager.isVisible();
          if (visible) {
            await windowManager.hide();
          } else {
            await windowManager.show();
            await windowManager.focus();
          }
        } catch (_) {}
      },
    );
  } catch (_) {
    // already taken — silent fall back
  }
}

LogicalKeyboardKey? _parseHotkey(String s) {
  switch (s.toUpperCase()) {
    case 'F1': return LogicalKeyboardKey.f1;
    case 'F2': return LogicalKeyboardKey.f2;
    case 'F3': return LogicalKeyboardKey.f3;
    case 'F4': return LogicalKeyboardKey.f4;
    case 'F5': return LogicalKeyboardKey.f5;
    case 'F6': return LogicalKeyboardKey.f6;
    case 'F7': return LogicalKeyboardKey.f7;
    case 'F8': return LogicalKeyboardKey.f8;
    case 'F9': return LogicalKeyboardKey.f9;
    case 'F10': return LogicalKeyboardKey.f10;
    case 'F11': return LogicalKeyboardKey.f11;
    case 'F12': return LogicalKeyboardKey.f12;
    case 'BACKQUOTE':
    case 'GRAVE':
    case '`':
      return LogicalKeyboardKey.backquote;
    default:
      return null;
  }
}

/// Live settings broadcast to the whole widget tree.
final ValueNotifier<rust.Settings> appSettings = ValueNotifier(
  const rust.Settings(
    theme: 'dark',
    fontFamily: 'JetBrains Mono',
    fontSize: 13.0,
    quakeHotkey: '',
    locale: 'system',
  ),
);

/// User-pickable accent. One of: rose, amber, emerald, sky, violet.
final ValueNotifier<String> appAccent = ValueNotifier('rose');

/// Compact-density toggle.
final ValueNotifier<bool> appDense = ValueNotifier(false);

// ============================================================================
// Design tokens — warm-leaning neutrals + single-chroma accent rotation
// ============================================================================

class _Pal {
  // Dark
  static const dBg0 = Color(0xFF15130F);
  static const dBg1 = Color(0xFF1A1814);
  static const dBg2 = Color(0xFF211E19);
  static const dBg3 = Color(0xFF2A2620);
  static const dLine = Color(0xFF2F2A23);
  static const dLine2 = Color(0xFF3A342C);
  static const dInk0 = Color(0xFFF7F3EC);
  static const dInk1 = Color(0xFFD4CDBF);
  static const dInk2 = Color(0xFF948B7C);
  static const dInk3 = Color(0xFF6A6358);
  static const dTBg = Color(0xFF16140F);
  static const dTFg = Color(0xFFE6DFD1);

  // Light
  static const lBg0 = Color(0xFFF3EFE7);
  static const lBg1 = Color(0xFFFAF6EE);
  static const lBg2 = Color(0xFFFFFFFF);
  static const lBg3 = Color(0xFFF0EBE0);
  static const lLine = Color(0xFFE2DCCF);
  static const lLine2 = Color(0xFFD4CDBE);
  static const lInk0 = Color(0xFF1A1814);
  static const lInk1 = Color(0xFF3B362D);
  static const lInk2 = Color(0xFF6C6557);
  static const lInk3 = Color(0xFF908976);
  static const lTBg = Color(0xFFF8F4EC);
  static const lTFg = Color(0xFF2A2620);

  // Accents — rotated by [appAccent]
  static const cRose = Color(0xFFE3667D);
  static const cAmber = Color(0xFFD99A3A);
  static const cEmerald = Color(0xFF4CAF86);
  static const cSky = Color(0xFF5D9BE8);
  static const cViolet = Color(0xFF9A7BE8);
  static const cSlate = Color(0xFF8A8475);
}

bool get _isLight => appSettings.value.theme == 'light';

Color get _bg0 => _isLight ? _Pal.lBg0 : _Pal.dBg0;
Color get _bg1 => _isLight ? _Pal.lBg1 : _Pal.dBg1;
Color get _bg2 => _isLight ? _Pal.lBg2 : _Pal.dBg2;
Color get _bg3 => _isLight ? _Pal.lBg3 : _Pal.dBg3;
Color get _line => _isLight ? _Pal.lLine : _Pal.dLine;
Color get _line2 => _isLight ? _Pal.lLine2 : _Pal.dLine2;
Color get _ink0 => _isLight ? _Pal.lInk0 : _Pal.dInk0;
Color get _ink1 => _isLight ? _Pal.lInk1 : _Pal.dInk1;
Color get _ink2 => _isLight ? _Pal.lInk2 : _Pal.dInk2;
Color get _ink3 => _isLight ? _Pal.lInk3 : _Pal.dInk3;
Color get _tBg => _isLight ? _Pal.lTBg : _Pal.dTBg;
Color get _tFg => _isLight ? _Pal.lTFg : _Pal.dTFg;

Color colorForAccent(String name) {
  switch (name) {
    case 'amber': return _Pal.cAmber;
    case 'emerald': return _Pal.cEmerald;
    case 'sky': return _Pal.cSky;
    case 'violet': return _Pal.cViolet;
    case 'slate': return _Pal.cSlate;
    case 'rose':
    default:
      return _Pal.cRose;
  }
}

Color get _acc => colorForAccent(appAccent.value);
Color get _accSoft => _acc.withValues(alpha: 0.18);
Color get _accDeep => Color.lerp(_acc, _Pal.dBg1, 0.4)!;

// ============================================================================
// Typography helpers
// ============================================================================

TextStyle _display({double size = 36, FontWeight weight = FontWeight.w500, Color? color, double letterSpacing = -0.5}) {
  return GoogleFonts.fraunces(
    fontSize: size,
    fontWeight: weight,
    height: 1.05,
    letterSpacing: letterSpacing,
    color: color ?? _ink0,
  );
}

TextStyle _sans({double size = 13.5, FontWeight weight = FontWeight.w400, Color? color, double letterSpacing = -0.05}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    height: 1.4,
    letterSpacing: letterSpacing,
    color: color ?? _ink0,
  );
}

TextStyle _mono({double size = 12, FontWeight weight = FontWeight.w400, Color? color, double letterSpacing = 0}) {
  return GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    height: 1.4,
    letterSpacing: letterSpacing,
    color: color ?? _ink1,
  );
}

TextStyle _eyebrow() => _mono(
      size: 10.5,
      weight: FontWeight.w500,
      color: _acc,
      letterSpacing: 1.5,
    );

TextStyle _blockHead() => _mono(
      size: 11,
      weight: FontWeight.w500,
      color: _ink1,
      letterSpacing: 1.6,
    );

TextStyle _blockSub() => _mono(
      size: 11,
      color: _ink3,
      letterSpacing: 0.4,
    );

TextStyle get _termStyle {
  final fam = appSettings.value.fontFamily;
  final size = appSettings.value.fontSize <= 0 ? 13.0 : appSettings.value.fontSize;
  if (fam.isEmpty || fam.toLowerCase().contains('jetbrains')) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      height: 1.55,
      color: _tFg,
    );
  }
  return TextStyle(
    fontFamily: fam,
    fontFamilyFallback: const [
      'JetBrains Mono',
      'Cascadia Mono',
      'Consolas',
      'Malgun Gothic',
      'Noto Sans Mono CJK KR',
      'Courier New',
    ],
    fontSize: size,
    height: 1.55,
    color: _tFg,
  );
}

// ============================================================================
// App
// ============================================================================

class TindraApp extends StatelessWidget {
  const TindraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appSettings, appAccent, appDense]),
      builder: (context, _) {
        final settings = appSettings.value;
        final isLight = settings.theme == 'light';
        final base = isLight
            ? ThemeData.light(useMaterial3: true)
            : ThemeData.dark(useMaterial3: true);
        return MaterialApp(
          title: 'Tindra',
          debugShowCheckedModeBanner: false,
          locale: settings.locale == 'system' ? null : Locale(settings.locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: base.copyWith(
            scaffoldBackgroundColor: _bg0,
            colorScheme: isLight
                ? ColorScheme.light(
                    primary: _acc,
                    onPrimary: Colors.white,
                    surface: _Pal.lBg1,
                    onSurface: _Pal.lInk0,
                    error: _Pal.cRose,
                  )
                : ColorScheme.dark(
                    primary: _acc,
                    onPrimary: _Pal.dBg0,
                    surface: _Pal.dBg1,
                    onSurface: _Pal.dInk0,
                    error: _Pal.cRose,
                  ),
            textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
              bodyColor: _ink0,
              displayColor: _ink0,
            ),
            iconTheme: IconThemeData(color: _ink2, size: 16),
            dividerColor: _line,
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: _bg2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _acc, width: 1.4),
              ),
              hintStyle: _mono(size: 12.5, color: _ink3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            ),
            tooltipTheme: TooltipThemeData(
              decoration: BoxDecoration(
                color: _bg3,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _line2),
              ),
              textStyle: _mono(size: 11, color: _ink1),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: _bg1,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: _line2),
              ),
              titleTextStyle: _display(size: 22, weight: FontWeight.w500, color: _ink0),
            ),
          ),
          home: const ShellScreen(),
        );
      },
    );
  }
}

// ============================================================================
// Data
// ============================================================================

enum _ConnState { connecting, connected, disconnected }

const String _localShellProfileId = '__local_shell__';

/// One live (or recently-live) SSH session.
class _SessionTab {
  _SessionTab({required this.profileId, required this.profileName});

  final String profileId;
  final String profileName;

  BigInt? sessionId;
  _ConnState state = _ConnState.connecting;
  rust.TerminalSnapshot? snapshot;
  StreamSubscription<rust.TerminalSnapshot>? outputSub;
  String? error;
  DateTime startedAt = DateTime.now();

  int cols = 120;
  int rows = 32;
  Timer? resizeDebounce;

  Future<void> dispose() async {
    resizeDebounce?.cancel();
    final id = sessionId;
    sessionId = null;
    if (id != null) {
      try {
        await rust.shellClose(sessionId: id);
      } catch (_) {}
    }
    final sub = outputSub;
    outputSub = null;
    sub?.cancel();
  }
}

class _TabGroup {
  _TabGroup({
    required this.profileName,
    required _SessionTab first,
  }) : sessions = [first];

  final String profileName;
  final List<_SessionTab> sessions;
  Axis splitAxis = Axis.horizontal;
  int activeIdx = 0;

  _SessionTab get active => sessions[activeIdx.clamp(0, sessions.length - 1)];

  Future<void> dispose() async {
    for (final s in sessions) {
      await s.dispose();
    }
  }
}

enum _View { sessions, profiles, files, forwards, keys, settings }

// ============================================================================
// Shell screen
// ============================================================================

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
  String? _selectedProfileId;
  bool _profilesLoading = true;

  // Tab state
  final List<_TabGroup> _tabs = [];
  int _activeIdx = -1;

  // View routing
  _View _view = _View.sessions;
  bool _paletteOpen = false;
  String _profileFilter = 'all';

  // ignore: unused_field
  String? _sidebarError;

  rust.Profile? get _selectedProfile =>
      _profiles.where((p) => p.id == _selectedProfileId).firstOrNull;

  rust.Profile? _profileById(String id) =>
      _profiles.where((p) => p.id == id).firstOrNull;

  _TabGroup? get _activeGroup =>
      (_activeIdx >= 0 && _activeIdx < _tabs.length) ? _tabs[_activeIdx] : null;

  _SessionTab? get _activeTab => _activeGroup?.active;

  @override
  void initState() {
    super.initState();
    _refreshProfiles();
  }

  // ---------------------- Profile CRUD ----------------------

  Future<void> _refreshProfiles() async {
    try {
      final list = await rust.listProfiles();
      setState(() {
        _profiles = list;
        _profilesLoading = false;
        if (_selectedProfileId == null && list.isNotEmpty) {
          _selectedProfileId = list.first.id;
        }
      });
    } catch (e) {
      setState(() {
        _profilesLoading = false;
        _sidebarError = e.toString();
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
      setState(() => _selectedProfileId = saved.id);
    } catch (e) {
      setState(() => _sidebarError = e.toString());
    }
  }

  Future<void> _deleteProfile(rust.Profile profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.deleteProfileQuestion),
          content: Text(l10n.deleteProfileContent(profile.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _Pal.cRose),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await rust.deleteProfile(id: profile.id);
      await _refreshProfiles();
      setState(() {
        if (_selectedProfileId == profile.id) {
          _selectedProfileId = _profiles.isEmpty ? null : _profiles.first.id;
        }
      });
    } catch (e) {
      setState(() => _sidebarError = e.toString());
    }
  }

  // ---------------------- Tab lifecycle ----------------------

  Future<void> _connectSelected({_TabGroup? splitInto, Axis? axis}) async {
    final p = _selectedProfile;
    if (p == null) return;

    final tab = _SessionTab(profileId: p.id, profileName: p.name);
    final group = splitInto;
    setState(() {
      if (group != null) {
        if (axis != null) group.splitAxis = axis;
        group.sessions.add(tab);
        group.activeIdx = group.sessions.length - 1;
      } else {
        _tabs.add(_TabGroup(profileName: p.name, first: tab));
        _activeIdx = _tabs.length - 1;
      }
      _view = _View.sessions;
    });

    try {
      final jump = rust.JumpHost(
        host: p.jumpHost,
        port: p.jumpPort == 0 ? 22 : p.jumpPort,
        username: p.jumpUsername,
        privateKeyPath: p.jumpPrivateKeyPath,
        passphrase: null,
      );
      final BigInt id;
      if (p.transport == 'telnet') {
        id = await rust.openShellTelnet(host: p.host, port: p.port, cols: tab.cols, rows: tab.rows);
      } else if (p.authMethod == 'agent') {
        id = await rust.openShellAgent(
          host: p.host, port: p.port, username: p.username,
          cols: tab.cols, rows: tab.rows, jump: jump,
        );
      } else {
        id = await rust.openShellPubkey(
          host: p.host, port: p.port, username: p.username,
          privateKeyPath: p.privateKeyPath,
          passphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
          cols: tab.cols, rows: tab.rows, jump: jump,
        );
      }
      tab.sessionId = id;
      tab.outputSub = rust.shellOutputStream(sessionId: id).listen(
        (snap) { tab.snapshot = snap; if (mounted) setState(() {}); },
        onError: (e) {
          tab.error = e.toString();
          tab.state = _ConnState.disconnected;
          if (mounted) setState(() {});
        },
        onDone: () {
          tab.state = _ConnState.disconnected;
          if (mounted) setState(() {});
        },
      );
      tab.state = _ConnState.connected;
      if (mounted) setState(() {});
      _passphrase.clear();
      _termFocus.requestFocus();
    } catch (e) {
      tab.error = e.toString();
      tab.state = _ConnState.disconnected;
      if (mounted) setState(() {});
    }
  }

  Future<void> _openLocalShell() async {
    final tab = _SessionTab(profileId: _localShellProfileId, profileName: 'Local Shell');
    setState(() {
      _tabs.add(_TabGroup(profileName: 'Local Shell', first: tab));
      _activeIdx = _tabs.length - 1;
      _view = _View.sessions;
    });
    await _connectLocalIntoExistingSession(tab);
  }

  Future<void> _connectLocalIntoExistingSession(_SessionTab tab) async {
    try {
      final id = await rust.openLocalShell(shell: null, cols: tab.cols, rows: tab.rows);
      tab.sessionId = id;
      tab.outputSub = rust.shellOutputStream(sessionId: id).listen(
        (snap) { tab.snapshot = snap; if (mounted) setState(() {}); },
        onError: (e) {
          tab.error = e.toString();
          tab.state = _ConnState.disconnected;
          if (mounted) setState(() {});
        },
        onDone: () {
          tab.state = _ConnState.disconnected;
          if (mounted) setState(() {});
        },
      );
      tab.state = _ConnState.connected;
      if (mounted) setState(() {});
      _termFocus.requestFocus();
    } catch (e) {
      tab.error = e.toString();
      tab.state = _ConnState.disconnected;
      if (mounted) setState(() {});
    }
  }

  Future<void> _connectIntoExistingSession(rust.Profile p, _SessionTab tab) async {
    try {
      final jump = rust.JumpHost(
        host: p.jumpHost,
        port: p.jumpPort == 0 ? 22 : p.jumpPort,
        username: p.jumpUsername,
        privateKeyPath: p.jumpPrivateKeyPath,
        passphrase: null,
      );
      final BigInt id;
      if (p.transport == 'telnet') {
        id = await rust.openShellTelnet(host: p.host, port: p.port, cols: tab.cols, rows: tab.rows);
      } else if (p.authMethod == 'agent') {
        id = await rust.openShellAgent(
          host: p.host, port: p.port, username: p.username,
          cols: tab.cols, rows: tab.rows, jump: jump,
        );
      } else {
        id = await rust.openShellPubkey(
          host: p.host, port: p.port, username: p.username,
          privateKeyPath: p.privateKeyPath,
          passphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
          cols: tab.cols, rows: tab.rows, jump: jump,
        );
      }
      tab.sessionId = id;
      tab.outputSub = rust.shellOutputStream(sessionId: id).listen(
        (snap) { tab.snapshot = snap; if (mounted) setState(() {}); },
        onError: (e) {
          tab.error = e.toString();
          tab.state = _ConnState.disconnected;
          if (mounted) setState(() {});
        },
        onDone: () {
          tab.state = _ConnState.disconnected;
          if (mounted) setState(() {});
        },
      );
      tab.state = _ConnState.connected;
      if (mounted) setState(() {});
      _passphrase.clear();
      _termFocus.requestFocus();
    } catch (e) {
      tab.error = e.toString();
      tab.state = _ConnState.disconnected;
      if (mounted) setState(() {});
    }
  }

  Future<void> _splitHorizontal() async {
    if (_activeGroup == null || _selectedProfile == null) return;
    await _connectSelected(splitInto: _activeGroup, axis: Axis.horizontal);
  }

  Future<void> _splitVertical() async {
    if (_activeGroup == null || _selectedProfile == null) return;
    await _connectSelected(splitInto: _activeGroup, axis: Axis.vertical);
  }

  Future<void> _closeActiveSession() async {
    final group = _activeGroup;
    if (group == null) return;
    if (group.sessions.length <= 1) {
      await _closeTab(_activeIdx);
      return;
    }
    final session = group.active;
    final idx = group.activeIdx;
    setState(() {
      group.sessions.removeAt(idx);
      if (group.activeIdx >= group.sessions.length) {
        group.activeIdx = group.sessions.length - 1;
      }
    });
    await session.dispose();
  }

  Future<void> _disconnectActive() async {
    final tab = _activeTab;
    if (tab == null) return;
    final id = tab.sessionId;
    if (id != null) {
      await rust.shellClose(sessionId: id);
    }
    final sub = tab.outputSub;
    tab.outputSub = null;
    sub?.cancel();
    tab.sessionId = null;
    tab.state = _ConnState.disconnected;
    if (mounted) setState(() {});
  }

  Future<void> _reconnectActive() async {
    final group = _activeGroup;
    final old = _activeTab;
    if (group == null || old == null) return;
    if (old.profileId == _localShellProfileId) {
      await old.dispose();
      final fresh = _SessionTab(profileId: _localShellProfileId, profileName: 'Local Shell');
      setState(() => group.sessions[group.activeIdx] = fresh);
      await _connectLocalIntoExistingSession(fresh);
      return;
    }
    final profile = _profileById(old.profileId);
    if (profile == null) return;
    await old.dispose();
    final fresh = _SessionTab(profileId: profile.id, profileName: profile.name);
    setState(() {
      group.sessions[group.activeIdx] = fresh;
      _selectedProfileId = profile.id;
    });
    await _connectIntoExistingSession(profile, fresh);
  }

  Future<void> _closeTab(int idx) async {
    if (idx < 0 || idx >= _tabs.length) return;
    final group = _tabs[idx];
    await group.dispose();
    setState(() {
      _tabs.removeAt(idx);
      if (_tabs.isEmpty) {
        _activeIdx = -1;
      } else if (_activeIdx >= _tabs.length) {
        _activeIdx = _tabs.length - 1;
      } else if (_activeIdx > idx) {
        _activeIdx -= 1;
      }
    });
  }

  void _switchTab(int idx) {
    if (idx == _activeIdx) return;
    setState(() => _activeIdx = idx);
    _termFocus.requestFocus();
  }

  // ---------------------- Terminal I/O ----------------------

  Future<void> _writeBytes(List<int> bytes) async {
    final tab = _activeTab;
    if (tab == null || tab.sessionId == null) return;
    try {
      await rust.shellWrite(sessionId: tab.sessionId!, data: bytes);
    } catch (e) {
      tab.error = e.toString();
      if (mounted) setState(() {});
    }
  }

  Future<void> _copyScreen() async {
    final text = _activeTab?.snapshot?.text;
    if (text == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    await _writeBytes(utf8.encode(text.replaceAll('\n', '\r')));
  }

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
      final shift = HardwareKeyboard.instance.isShiftPressed;
      if (logical == LogicalKeyboardKey.keyT ||
          logical == LogicalKeyboardKey.keyW ||
          logical == LogicalKeyboardKey.tab ||
          logical == LogicalKeyboardKey.comma ||
          logical == LogicalKeyboardKey.keyK ||
          (shift &&
              (logical == LogicalKeyboardKey.keyC ||
                  logical == LogicalKeyboardKey.keyH ||
                  logical == LogicalKeyboardKey.keyR ||
                  logical == LogicalKeyboardKey.keyV ||
                  logical == LogicalKeyboardKey.keyE))) {
        return null;
      }
      final ctrlLetters = <LogicalKeyboardKey, int>{
        LogicalKeyboardKey.keyA: 0x01, LogicalKeyboardKey.keyB: 0x02,
        LogicalKeyboardKey.keyC: 0x03, LogicalKeyboardKey.keyD: 0x04,
        LogicalKeyboardKey.keyE: 0x05, LogicalKeyboardKey.keyF: 0x06,
        LogicalKeyboardKey.keyG: 0x07, LogicalKeyboardKey.keyH: 0x08,
        LogicalKeyboardKey.keyI: 0x09, LogicalKeyboardKey.keyJ: 0x0A,
        LogicalKeyboardKey.keyK: 0x0B, LogicalKeyboardKey.keyL: 0x0C,
        LogicalKeyboardKey.keyM: 0x0D, LogicalKeyboardKey.keyN: 0x0E,
        LogicalKeyboardKey.keyO: 0x0F, LogicalKeyboardKey.keyP: 0x10,
        LogicalKeyboardKey.keyQ: 0x11, LogicalKeyboardKey.keyR: 0x12,
        LogicalKeyboardKey.keyS: 0x13, LogicalKeyboardKey.keyT: 0x14,
        LogicalKeyboardKey.keyU: 0x15, LogicalKeyboardKey.keyV: 0x16,
        LogicalKeyboardKey.keyW: 0x17, LogicalKeyboardKey.keyX: 0x18,
        LogicalKeyboardKey.keyY: 0x19, LogicalKeyboardKey.keyZ: 0x1A,
      };
      final direct = ctrlLetters[logical];
      if (direct != null) return [direct];

      if (logical == LogicalKeyboardKey.space) return [0x00];
      if (logical == LogicalKeyboardKey.bracketLeft) return [0x1B];
      if (logical == LogicalKeyboardKey.backslash) return [0x1C];
      if (logical == LogicalKeyboardKey.bracketRight) return [0x1D];
      if (logical == LogicalKeyboardKey.digit6) return [0x1E];
      if (logical == LogicalKeyboardKey.minus) return [0x1F];

      final ch = event.character;
      if (ch != null && ch.isNotEmpty) {
        final code = ch.toUpperCase().codeUnitAt(0);
        if (code >= 0x40 && code <= 0x5F) return [code - 0x40];
      }
    }
    if (alt) {
      final ch = event.character;
      if (ch != null && ch.isNotEmpty) return [0x1b, ...utf8.encode(ch)];
    }
    final ch = event.character;
    if (ch != null && ch.isNotEmpty) return utf8.encode(ch);
    return null;
  }

  KeyEventResult _onTermKey(FocusNode node, KeyEvent event) {
    final tab = _activeTab;
    if (tab == null || tab.state != _ConnState.connected) {
      return KeyEventResult.ignored;
    }
    final bytes = _keyEventToBytes(event);
    if (bytes != null) {
      _writeBytes(bytes);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scheduleResize(int cols, int rows) {
    final tab = _activeTab;
    if (tab == null) return;
    if (cols == tab.cols && rows == tab.rows) return;
    tab.resizeDebounce?.cancel();
    tab.resizeDebounce = Timer(const Duration(milliseconds: 200), () {
      final id = tab.sessionId;
      if (id == null || tab.state != _ConnState.connected) return;
      tab.cols = cols;
      tab.rows = rows;
      rust.shellResize(sessionId: id, cols: cols, rows: rows);
    });
  }

  // ---------------------- Dialogs / palette wiring ----------------------

  Future<void> _openSettingsView() async {
    setState(() => _view = _View.settings);
  }

  Future<void> _saveSettings(rust.Settings s) async {
    try {
      await rust.saveSettings(settings: s);
      appSettings.value = s;
    } catch (e) {
      if (mounted) setState(() => _sidebarError = e.toString());
    }
  }

  void _togglePalette() => setState(() => _paletteOpen = !_paletteOpen);
  void _closePalette() => setState(() => _paletteOpen = false);

  @override
  void dispose() {
    for (final t in _tabs) {
      t.dispose();
    }
    _passphrase.dispose();
    _termFocus.dispose();
    super.dispose();
  }

  // ---------------------- Build ----------------------

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyT, control: true): _NewTabIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, control: true): _CloseTabIntent(),
        SingleActivator(LogicalKeyboardKey.tab, control: true): _NextTabIntent(),
        SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true): _PrevTabIntent(),
        SingleActivator(LogicalKeyboardKey.comma, control: true): _SettingsIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true): _PaletteIntent(),
        SingleActivator(LogicalKeyboardKey.keyH, control: true, shift: true): _SplitHorizontalIntent(),
        SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true): _SplitVerticalIntent(),
        SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): _CopyScreenIntent(),
        SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true): _PasteClipboardIntent(),
        SingleActivator(LogicalKeyboardKey.keyR, control: true, shift: true): _ReconnectIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewTabIntent: CallbackAction<_NewTabIntent>(onInvoke: (_) {
            if (_selectedProfile != null) _connectSelected();
            return null;
          }),
          _CloseTabIntent: CallbackAction<_CloseTabIntent>(onInvoke: (_) {
            _closeActiveSession();
            return null;
          }),
          _NextTabIntent: CallbackAction<_NextTabIntent>(onInvoke: (_) {
            if (_tabs.length >= 2) _switchTab((_activeIdx + 1) % _tabs.length);
            return null;
          }),
          _PrevTabIntent: CallbackAction<_PrevTabIntent>(onInvoke: (_) {
            if (_tabs.length >= 2) _switchTab((_activeIdx - 1 + _tabs.length) % _tabs.length);
            return null;
          }),
          _SettingsIntent: CallbackAction<_SettingsIntent>(onInvoke: (_) {
            _openSettingsView();
            return null;
          }),
          _PaletteIntent: CallbackAction<_PaletteIntent>(onInvoke: (_) {
            _togglePalette();
            return null;
          }),
          _SplitHorizontalIntent: CallbackAction<_SplitHorizontalIntent>(onInvoke: (_) {
            _splitHorizontal();
            return null;
          }),
          _SplitVerticalIntent: CallbackAction<_SplitVerticalIntent>(onInvoke: (_) {
            _splitVertical();
            return null;
          }),
          _CopyScreenIntent: CallbackAction<_CopyScreenIntent>(onInvoke: (_) {
            _copyScreen();
            return null;
          }),
          _PasteClipboardIntent: CallbackAction<_PasteClipboardIntent>(onInvoke: (_) {
            _pasteClipboard();
            return null;
          }),
          _ReconnectIntent: CallbackAction<_ReconnectIntent>(onInvoke: (_) {
            _reconnectActive();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: _bg0,
            body: Stack(
              children: [
                Column(
                  children: [
                    _TitleBar(
                      title: _titleText(),
                      onPalette: _togglePalette,
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Sidebar(
                            view: _view,
                            sessionsCount: _tabs.length,
                            onView: (v) => setState(() => _view = v),
                            onPalette: _togglePalette,
                          ),
                          Expanded(child: _mainArea()),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_paletteOpen)
                  _CommandPalette(
                    profiles: _profiles,
                    onClose: _closePalette,
                    onOpenProfile: (p) {
                      _closePalette();
                      setState(() => _selectedProfileId = p.id);
                      _connectSelected();
                    },
                    onView: (v) {
                      _closePalette();
                      setState(() => _view = v);
                    },
                    onLocalShell: () {
                      _closePalette();
                      _openLocalShell();
                    },
                    onSplitH: () {
                      _closePalette();
                      _splitHorizontal();
                    },
                    onSplitV: () {
                      _closePalette();
                      _splitVertical();
                    },
                    onNewProfile: () {
                      _closePalette();
                      _openProfileDialog();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _titleText() {
    final t = _activeTab;
    if (_view == _View.sessions && t != null) {
      return 'Tindra · ${t.profileName}';
    }
    return 'Tindra';
  }

  Widget _mainArea() {
    // Show session view whenever sessions exist and we're on the Sessions
    // route. Otherwise show the route's empty/list view.
    switch (_view) {
      case _View.sessions:
        if (_tabs.isEmpty) return _emptySessions();
        return _sessionView();
      case _View.profiles:
        return _profilesView();
      case _View.files:
        return _filesView();
      case _View.forwards:
        return _forwardsView();
      case _View.keys:
        return _keysView();
      case _View.settings:
        return _settingsView();
    }
  }

  // ---------------------- Views ----------------------

  Widget _emptySessions() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ViewHead(
              eyebrow: 'home',
              title: _greeting(),
              lede: '${_tabs.length} live sessions · ${_profiles.length} profiles · '
                  'sync caught up moments ago',
              actions: [
                _GhostButton(
                  icon: Icons.terminal_outlined,
                  label: 'Local shell',
                  onTap: _openLocalShell,
                ),
                _PrimaryButton(
                  icon: Icons.add,
                  label: 'New profile',
                  onTap: () => _openProfileDialog(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _BlockHead(title: 'Quickstart', sub: 'press ⌘K to summon the palette'),
            Container(
              decoration: BoxDecoration(
                color: _bg1,
                border: Border.all(color: _line, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: _bg2,
                        border: Border.all(color: _line2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(r'$', style: GoogleFonts.jetBrainsMono(
                        fontSize: 20, color: _acc, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 14),
                    Text('No open sessions', style: _display(size: 22)),
                    const SizedBox(height: 6),
                    Text(
                      'Pick a profile, or press ⌘K to run a command.',
                      style: _sans(color: _ink2, size: 13.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _BlockHead(
              title: 'Profiles',
              tools: _filterChips(),
            ),
            _profilesGrid(),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    final phase = h < 5 ? 'evening' : h < 12 ? 'morning' : h < 18 ? 'afternoon' : 'evening';
    return 'Good $phase.';
  }

  List<Widget> _filterChips() {
    final tags = <String>{'all'};
    for (final p in _profiles) {
      for (final t in (p.notes.isEmpty ? <String>[] : p.notes.split(',').map((e) => e.trim()))) {
        if (t.isNotEmpty) tags.add(t);
      }
    }
    return [
      for (final t in tags.take(6))
        _Chip(
          label: t,
          on: _profileFilter == t,
          onTap: () => setState(() => _profileFilter = t),
        ),
    ];
  }

  Widget _profilesGrid() {
    if (_profilesLoading) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 1.6, color: _acc),
        )),
      );
    }
    if (_profiles.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: _bg1,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No profiles yet', style: _display(size: 22)),
            const SizedBox(height: 6),
            Text('Create one to start connecting.', style: _sans(color: _ink2)),
            const SizedBox(height: 14),
            _PrimaryButton(icon: Icons.add, label: 'New profile', onTap: () => _openProfileDialog()),
          ],
        ),
      );
    }
    final shown = _profiles.where((p) {
      if (_profileFilter == 'all') return true;
      final tags = p.notes.split(',').map((e) => e.trim());
      return tags.contains(_profileFilter);
    }).toList();
    return LayoutBuilder(
      builder: (context, c) {
        final dense = appDense.value;
        final minW = dense ? 220.0 : 280.0;
        final cols = (c.maxWidth / minW).floor().clamp(1, 6);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final p in shown)
              SizedBox(
                width: (c.maxWidth - (cols - 1) * 12) / cols,
                child: _ProfileCard(
                  profile: p,
                  selected: p.id == _selectedProfileId,
                  dense: dense,
                  onSelect: () => setState(() => _selectedProfileId = p.id),
                  onOpen: () {
                    setState(() => _selectedProfileId = p.id);
                    _connectSelected();
                  },
                  onEdit: () => _openProfileDialog(existing: p),
                  onDelete: () => _deleteProfile(p),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _sessionView() => _SessionPane(
        tabs: _tabs,
        activeIdx: _activeIdx,
        termFocus: _termFocus,
        onTermKey: _onTermKey,
        onCloseTab: _closeTab,
        onSwitchTab: _switchTab,
        onAddTab: _connectSelected,
        onSplitH: _splitHorizontal,
        onSplitV: _splitVertical,
        onCopy: _copyScreen,
        onPaste: _pasteClipboard,
        onReconnect: _reconnectActive,
        onDisconnect: _disconnectActive,
        scheduleResize: _scheduleResize,
        selectedProfile: _selectedProfile,
        profileById: _profileById,
      );

  Widget _profilesView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ViewHead(
            eyebrow: 'profiles',
            title: '${_profiles.length} profiles',
            lede: 'Local-only · encrypted at rest with age. Pair another device to sync.',
            actions: [
              _GhostButton(icon: Icons.key_outlined, label: 'Import keys', onTap: () {}),
              _PrimaryButton(icon: Icons.add, label: 'New profile', onTap: () => _openProfileDialog()),
            ],
          ),
          const SizedBox(height: 24),
          _ProfilesTable(
            profiles: _profiles,
            onOpen: (p) {
              setState(() => _selectedProfileId = p.id);
              _connectSelected();
            },
            onEdit: (p) => _openProfileDialog(existing: p),
            onDelete: _deleteProfile,
          ),
          const SizedBox(height: 8),
          if (_selectedProfile != null) _selectedProfileFooter(_selectedProfile!),
        ],
      ),
    );
  }

  /// Hidden affordance the integration tests rely on: a button labelled
  /// `Open profileName` mirroring the tab-bar trailing plus button.
  Widget _selectedProfileFooter(rust.Profile p) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Tooltip(
            message: 'Open ${p.name}',
            child: FilledButton.icon(
              onPressed: _connectSelected,
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: Text(
                'Open ${p.name}',
                style: _sans(size: 13, weight: FontWeight.w600, color: _isLight ? Colors.white : _Pal.dBg0),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _ink0,
                foregroundColor: _isLight ? Colors.white : _Pal.dBg0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filesView() => _FilesView(profiles: _profiles);
  Widget _forwardsView() => _ForwardsView(profiles: _profiles, selectedProfile: _selectedProfile);
  Widget _keysView() => const _KeysView();
  Widget _settingsView() => _SettingsView(
        onSave: _saveSettings,
      );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ============================================================================
// Title bar
// ============================================================================

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title, required this.onPalette});
  final String title;
  final VoidCallback onPalette;

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bg1, _bg0],
          ),
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const _TrafficLights(),
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: _mono(size: 12, color: _ink2, letterSpacing: 0.3),
                ),
              ),
            ),
            DragToMoveArea(child: const SizedBox(width: 0)),
            _IconBtn(icon: Icons.search, tooltip: '⌘K', onTap: onPalette),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _TrafficLights extends StatelessWidget {
  const _TrafficLights();
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c) => Container(
      width: 12, height: 12,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    return Row(
      children: [
        InkWell(onTap: () async => windowManager.close(), child: dot(const Color(0xFFEC6A5E))),
        const SizedBox(width: 8),
        InkWell(onTap: () async => windowManager.minimize(), child: dot(const Color(0xFFF4BF4F))),
        const SizedBox(width: 8),
        InkWell(onTap: () async {
          if (await windowManager.isMaximized()) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        }, child: dot(const Color(0xFF61C554))),
      ],
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({required this.icon, required this.onTap, this.tooltip, this.iconSize = 14, this.danger = false});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double iconSize;
  final bool danger;
  static const double size = 28;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final color = !_hover
        ? _ink2
        : (widget.danger ? _Pal.cRose : _ink0);
    final btn = MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _IconBtn.size, height: _IconBtn.size,
          decoration: BoxDecoration(
            color: _hover ? _bg2 : null,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: widget.iconSize, color: color),
        ),
      ),
    );
    if (widget.tooltip == null) return btn;
    return Tooltip(message: widget.tooltip!, child: btn);
  }
}

// ============================================================================
// Sidebar
// ============================================================================

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.view,
    required this.sessionsCount,
    required this.onView,
    required this.onPalette,
  });

  final _View view;
  final int sessionsCount;
  final ValueChanged<_View> onView;
  final VoidCallback onPalette;

  @override
  Widget build(BuildContext context) {
    final items = <_NavSpec>[
      _NavSpec(_View.sessions, Icons.terminal_outlined, 'Sessions', sessionsCount > 0 ? '$sessionsCount' : null),
      _NavSpec(_View.profiles, Icons.public, 'Profiles', null),
      _NavSpec(_View.files, Icons.folder_outlined, 'Files', null),
      _NavSpec(_View.forwards, Icons.swap_horiz, 'Forwards', null),
      _NavSpec(_View.keys, Icons.vpn_key_outlined, 'Host keys', null),
      _NavSpec(_View.settings, Icons.tune, 'Settings', null),
    ];
    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: _bg1,
        border: Border(right: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Brand(),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final it in items)
                  _NavItem(
                    spec: it,
                    active: it.view == view,
                    onTap: () => onView(it.view),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _PaletteTrigger(onTap: onPalette),
          const SizedBox(height: 10),
          const _SyncRow(),
        ],
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.view, this.icon, this.label, this.badge);
  final _View view;
  final IconData icon;
  final String label;
  final String? badge;
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          _BrandLogo(accent: _acc),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tindra',
                style: _display(size: 19, weight: FontWeight.w600, color: _ink0, letterSpacing: -0.2),
              ),
              const SizedBox(height: 1),
              Text(
                'V0.1 · EARLY',
                style: _mono(size: 10, color: _ink3, letterSpacing: 1.3, weight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent,
            Color.lerp(accent, Colors.black, 0.25)!,
          ],
        ),
        border: Border.all(color: Color.lerp(accent, Colors.black, 0.5)!),
      ),
      alignment: Alignment.center,
      child: Transform.rotate(
        angle: 0.785398, // 45deg
        child: Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: _Pal.dInk0, width: 2),
              left: BorderSide(color: _Pal.dInk0, width: 2),
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.spec, required this.active, required this.onTap});
  final _NavSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  Widget? _badgeChip(bool active) {
    final b = widget.spec.badge;
    if (b == null) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: active ? _accSoft : _bg3,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(b, style: _mono(size: 10, color: active ? _acc : _ink1, weight: FontWeight.w500)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final hovering = _hover && !active;
    final bg = active ? _bg2 : (hovering ? _bg2 : Colors.transparent);
    final color = active ? _ink0 : (hovering ? _ink1 : _ink2);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(color: active ? _acc : Colors.transparent, width: 2),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.spec.icon, size: 17, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.spec.label,
                  style: _sans(size: 13.5, color: color, weight: FontWeight.w500),
                ),
              ),
              ?_badgeChip(active),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteTrigger extends StatefulWidget {
  const _PaletteTrigger({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_PaletteTrigger> createState() => _PaletteTriggerState();
}

class _PaletteTriggerState extends State<_PaletteTrigger> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _bg2,
            border: Border.all(color: _hover ? _line2 : _line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 14, color: _hover ? _ink1 : _ink2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search · run',
                  style: _sans(size: 12.5, color: _hover ? _ink1 : _ink2),
                ),
              ),
              _Kbd('⌘K'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncRow extends StatelessWidget {
  const _SyncRow();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: _Pal.cEmerald,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _Pal.cEmerald.withValues(alpha: 0.18), blurRadius: 0, spreadRadius: 3),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text('sync · ', style: _mono(size: 11, color: _ink3)),
          Text('paired (2)', style: _mono(size: 11, color: _ink1)),
        ],
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _bg3,
        border: Border.all(color: _line2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: _mono(size: 11, color: _ink1)),
    );
  }
}

// ============================================================================
// Intents
// ============================================================================

class _NewTabIntent extends Intent { const _NewTabIntent(); }
class _CloseTabIntent extends Intent { const _CloseTabIntent(); }
class _NextTabIntent extends Intent { const _NextTabIntent(); }
class _PrevTabIntent extends Intent { const _PrevTabIntent(); }
class _SettingsIntent extends Intent { const _SettingsIntent(); }
class _PaletteIntent extends Intent { const _PaletteIntent(); }
class _SplitHorizontalIntent extends Intent { const _SplitHorizontalIntent(); }
class _SplitVerticalIntent extends Intent { const _SplitVerticalIntent(); }
class _CopyScreenIntent extends Intent { const _CopyScreenIntent(); }
class _PasteClipboardIntent extends Intent { const _PasteClipboardIntent(); }
class _ReconnectIntent extends Intent { const _ReconnectIntent(); }

// ============================================================================
// Command palette
// ============================================================================

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({
    required this.profiles,
    required this.onClose,
    required this.onOpenProfile,
    required this.onView,
    required this.onLocalShell,
    required this.onSplitH,
    required this.onSplitV,
    required this.onNewProfile,
  });
  final List<rust.Profile> profiles;
  final VoidCallback onClose;
  final ValueChanged<rust.Profile> onOpenProfile;
  final ValueChanged<_View> onView;
  final VoidCallback onLocalShell;
  final VoidCallback onSplitH;
  final VoidCallback onSplitV;
  final VoidCallback onNewProfile;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _q = TextEditingController();
  final _focus = FocusNode();
  late final List<_PaletteCmd> _cmds;

  @override
  void initState() {
    super.initState();
    _cmds = [
      _PaletteCmd(icon: Icons.add, label: 'New profile', hint: '⌘N', run: widget.onNewProfile),
      _PaletteCmd(icon: Icons.terminal_outlined, label: 'Open local shell', hint: '⌘L', run: widget.onLocalShell),
      _PaletteCmd(icon: Icons.splitscreen_outlined, label: 'Split right', hint: '⌘⇧H', run: widget.onSplitH),
      _PaletteCmd(icon: Icons.horizontal_split_outlined, label: 'Split down', hint: '⌘⇧E', run: widget.onSplitV),
      _PaletteCmd(icon: Icons.folder_outlined, label: 'Toggle SFTP browser', hint: '⌘B', run: () => widget.onView(_View.files)),
      _PaletteCmd(icon: Icons.swap_horiz, label: 'Forwards', hint: null, run: () => widget.onView(_View.forwards)),
      _PaletteCmd(icon: Icons.vpn_key_outlined, label: 'Host keys', hint: null, run: () => widget.onView(_View.keys)),
      _PaletteCmd(icon: Icons.tune, label: 'Settings', hint: '⌘,', run: () => widget.onView(_View.settings)),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.toLowerCase();
    final profMatches = widget.profiles.where((p) =>
      q.isEmpty || p.name.toLowerCase().contains(q) || p.host.toLowerCase().contains(q)).toList();
    final cmdMatches = _cmds.where((c) => q.isEmpty || c.label.toLowerCase().contains(q)).toList();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(color: const Color(0x95080604)),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.10),
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: 640,
                  decoration: BoxDecoration(
                    color: _bg1,
                    border: Border.all(color: _line2),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 40, offset: const Offset(0, 12)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 16, color: _ink2),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                focusNode: _focus,
                                controller: _q,
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) {
                                  if (profMatches.isNotEmpty) {
                                    widget.onOpenProfile(profMatches.first);
                                  } else if (cmdMatches.isNotEmpty) {
                                    cmdMatches.first.run();
                                  }
                                },
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Run a command, or jump to a profile…',
                                  hintStyle: _display(size: 22, color: _ink3, weight: FontWeight.w500),
                                ),
                                style: _display(size: 22, color: _ink0, weight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _Kbd('esc'),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (profMatches.isNotEmpty) _section('PROFILES'),
                              for (final p in profMatches.take(5))
                                _palItem(
                                  leading: _BarMark(accent: _accentForProfile(p)),
                                  title: p.name,
                                  sub: '${p.username}@${p.host}',
                                  hint: '⏎ open',
                                  onTap: () => widget.onOpenProfile(p),
                                ),
                              if (cmdMatches.isNotEmpty) _section('COMMANDS'),
                              for (final c in cmdMatches)
                                _palItem(
                                  leading: Icon(c.icon, size: 14, color: _ink2),
                                  title: c.label,
                                  sub: null,
                                  hint: c.hint,
                                  onTap: () { widget.onClose(); c.run(); },
                                ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: _line))),
                        child: Row(
                          children: [
                            _Kbd('↑↓'), const SizedBox(width: 6), Text('navigate', style: _mono(size: 10.5, color: _ink3)),
                            const SizedBox(width: 14),
                            _Kbd('⏎'), const SizedBox(width: 6), Text('select', style: _mono(size: 10.5, color: _ink3)),
                            const Spacer(),
                            _Kbd('⌘K'), const SizedBox(width: 6), Text('close', style: _mono(size: 10.5, color: _ink3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text(label, style: _mono(size: 10, color: _ink3, letterSpacing: 1.5, weight: FontWeight.w500)),
      );

  Widget _palItem({required Widget leading, required String title, required String? sub, required String? hint, required VoidCallback onTap}) {
    return _PalItem(leading: leading, title: title, sub: sub, hint: hint, onTap: onTap);
  }
}

class _PaletteCmd {
  const _PaletteCmd({required this.icon, required this.label, required this.hint, required this.run});
  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback run;
}

class _PalItem extends StatefulWidget {
  const _PalItem({required this.leading, required this.title, required this.sub, required this.hint, required this.onTap});
  final Widget leading;
  final String title;
  final String? sub;
  final String? hint;
  final VoidCallback onTap;
  @override
  State<_PalItem> createState() => _PalItemState();
}

class _PalItemState extends State<_PalItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
          decoration: BoxDecoration(
            color: _hover ? _bg2 : null,
            border: Border(left: BorderSide(color: _hover ? _acc : Colors.transparent, width: 2)),
          ),
          child: Row(
            children: [
              SizedBox(width: 16, child: Center(child: widget.leading)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.title, style: _sans(size: 13.5, color: _ink0, weight: FontWeight.w500)),
                    if (widget.sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(widget.sub!, style: _mono(size: 11.5, color: _ink3)),
                      ),
                  ],
                ),
              ),
              if (widget.hint != null) Text(widget.hint!, style: _mono(size: 11, color: _ink3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Session pane: tab strip + terminal + footer
// ============================================================================

class _SessionPane extends StatelessWidget {
  const _SessionPane({
    required this.tabs,
    required this.activeIdx,
    required this.termFocus,
    required this.onTermKey,
    required this.onCloseTab,
    required this.onSwitchTab,
    required this.onAddTab,
    required this.onSplitH,
    required this.onSplitV,
    required this.onCopy,
    required this.onPaste,
    required this.onReconnect,
    required this.onDisconnect,
    required this.scheduleResize,
    required this.selectedProfile,
    required this.profileById,
  });

  final List<_TabGroup> tabs;
  final int activeIdx;
  final FocusNode termFocus;
  final KeyEventResult Function(FocusNode, KeyEvent) onTermKey;
  final Future<void> Function(int) onCloseTab;
  final void Function(int) onSwitchTab;
  final Future<void> Function() onAddTab;
  final Future<void> Function() onSplitH;
  final Future<void> Function() onSplitV;
  final Future<void> Function() onCopy;
  final Future<void> Function() onPaste;
  final Future<void> Function() onReconnect;
  final Future<void> Function() onDisconnect;
  final void Function(int, int) scheduleResize;
  final rust.Profile? selectedProfile;
  final rust.Profile? Function(String) profileById;

  @override
  Widget build(BuildContext context) {
    final group = (activeIdx >= 0 && activeIdx < tabs.length) ? tabs[activeIdx] : null;
    final tab = group?.active;
    final profile = tab == null
        ? null
        : (tab.profileId == _localShellProfileId
            ? null
            : profileById(tab.profileId));
    return Column(
      children: [
        _TabStrip(
          tabs: tabs,
          activeIdx: activeIdx,
          onSwitch: onSwitchTab,
          onClose: onCloseTab,
          onAdd: onAddTab,
          onSplitH: onSplitH,
          onSplitV: onSplitV,
          selectedProfile: selectedProfile,
          profileById: profileById,
        ),
        Expanded(
          child: Container(
            color: _tBg,
            child: Column(
              children: [
                if (tab != null)
                  _TermMeta(
                    tab: tab,
                    profile: profile,
                    onCopy: onCopy,
                    onPaste: onPaste,
                    onReconnect: onReconnect,
                  ),
                Expanded(
                  child: Focus(
                    focusNode: termFocus,
                    autofocus: false,
                    onKeyEvent: onTermKey,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: termFocus.requestFocus,
                      child: _splitView(group),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _SessionFooter(tab: tab, profile: profile),
      ],
    );
  }

  Widget _splitView(_TabGroup? group) {
    if (group == null || group.sessions.isEmpty) {
      return const SizedBox.shrink();
    }
    if (group.sessions.length == 1) {
      return _termBody(group.sessions.first, true);
    }
    final children = <Widget>[];
    for (var i = 0; i < group.sessions.length; i++) {
      final s = group.sessions[i];
      final isActive = i == group.activeIdx;
      children.add(Expanded(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive ? _acc : _line,
              width: isActive ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          margin: const EdgeInsets.all(4),
          child: _termBody(s, isActive),
        ),
      ));
    }
    return group.splitAxis == Axis.horizontal
        ? Row(children: children)
        : Column(children: children);
  }

  Widget _termBody(_SessionTab tab, bool isFocused) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final probe = TextPainter(
          text: TextSpan(text: 'M', style: _termStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final charWidth = probe.width;
        final lineHeight = probe.height;
        probe.dispose();

        const padding = 14.0;
        final availW = constraints.maxWidth - padding * 2;
        final availH = constraints.maxHeight - padding * 2;
        final fitCols = (availW / charWidth).floor().clamp(20, 400);
        final fitRows = (availH / lineHeight).floor().clamp(8, 200);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          scheduleResize(fitCols, fitRows);
        });

        return Padding(
          padding: const EdgeInsets.all(padding),
          child: _CellGrid(
            tab: tab,
            isFocused: isFocused && termFocus.hasFocus,
            charWidth: charWidth,
            lineHeight: lineHeight,
          ),
        );
      },
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.activeIdx,
    required this.onSwitch,
    required this.onClose,
    required this.onAdd,
    required this.onSplitH,
    required this.onSplitV,
    required this.selectedProfile,
    required this.profileById,
  });

  final List<_TabGroup> tabs;
  final int activeIdx;
  final void Function(int) onSwitch;
  final Future<void> Function(int) onClose;
  final Future<void> Function() onAdd;
  final Future<void> Function() onSplitH;
  final Future<void> Function() onSplitV;
  final rust.Profile? selectedProfile;
  final rust.Profile? Function(String) profileById;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: _bg1,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length + 1,
              itemBuilder: (context, i) {
                if (i == tabs.length) {
                  return _addTabButton();
                }
                return _TabPill(
                  group: tabs[i],
                  index: i,
                  active: i == activeIdx,
                  accent: _accentForGroup(tabs[i]),
                  onTap: () => onSwitch(i),
                  onClose: () => onClose(i),
                );
              },
            ),
          ),
          _IconBtn(icon: Icons.splitscreen_outlined, tooltip: 'Split right', onTap: () => onSplitH()),
          _IconBtn(icon: Icons.horizontal_split_outlined, tooltip: 'Split down', onTap: () => onSplitV()),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Color _accentForGroup(_TabGroup g) {
    final id = g.sessions.first.profileId;
    if (id == _localShellProfileId) return _Pal.cSlate;
    final p = profileById(id);
    if (p == null) return _acc;
    return _accentForProfile(p);
  }

  Widget _addTabButton() {
    final tooltip = selectedProfile == null
        ? 'Pick a profile to open'
        : 'Open ${selectedProfile!.name}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: selectedProfile == null ? null : onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Icon(Icons.add, size: 14, color: _ink3),
          ),
        ),
      ),
    );
  }
}

class _TabPill extends StatefulWidget {
  const _TabPill({
    required this.group,
    required this.index,
    required this.active,
    required this.accent,
    required this.onTap,
    required this.onClose,
  });

  final _TabGroup group;
  final int index;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_TabPill> createState() => _TabPillState();
}

class _TabPillState extends State<_TabPill> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.group.active;
    final color = widget.active ? _ink0 : (_hover ? _ink1 : _ink2);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        margin: const EdgeInsets.only(right: 2, top: 0, bottom: 0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: widget.active ? _bg0 : (_hover ? _bg2 : Colors.transparent),
              border: widget.active
                  ? Border(
                      top: BorderSide(color: widget.accent, width: 2),
                      left: BorderSide(color: _line),
                      right: BorderSide(color: _line),
                    )
                  : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            padding: EdgeInsets.fromLTRB(12, widget.active ? 6 : 8, 10, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 6×6 status dot — integration tests count these as "tabs".
                Container(
                  width: 6, height: 6,
                  constraints: const BoxConstraints.tightFor(width: 6, height: 6),
                  decoration: BoxDecoration(
                    color: _stateColor(s.state, widget.accent),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.group.sessions.length > 1
                      ? '${widget.group.profileName} ·${widget.group.sessions.length}'
                      : widget.group.profileName,
                  style: _mono(size: 12.5, color: color, weight: widget.active ? FontWeight.w500 : FontWeight.w400),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: ValueKey('tab-close-${widget.index}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 11, color: _ink3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _stateColor(_ConnState s, Color accent) {
    switch (s) {
      case _ConnState.connecting: return _Pal.cAmber;
      case _ConnState.connected:
        // The integration tests assert against the design's emerald shade.
        return _Pal.cEmerald;
      case _ConnState.disconnected: return _Pal.cRose;
    }
  }
}

class _TermMeta extends StatelessWidget {
  const _TermMeta({required this.tab, required this.profile, required this.onCopy, required this.onPaste, required this.onReconnect});
  final _SessionTab tab;
  final rust.Profile? profile;
  final Future<void> Function() onCopy;
  final Future<void> Function() onPaste;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final connected = tab.state == _ConnState.connected;
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: _bg1,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (connected) ...[
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: _Pal.cEmerald,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _Pal.cEmerald.withValues(alpha: 0.2), blurRadius: 0, spreadRadius: 3)],
              ),
            ),
            const SizedBox(width: 6),
            Text('connected', style: _mono(size: 11.5, color: _Pal.cEmerald)),
          ] else if (tab.state == _ConnState.connecting) ...[
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.4, color: _Pal.cAmber),
            ),
            const SizedBox(width: 6),
            Text('connecting', style: _mono(size: 11.5, color: _Pal.cAmber)),
          ] else ...[
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: _Pal.cRose, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text('offline', style: _mono(size: 11.5, color: _Pal.cRose)),
          ],
          const SizedBox(width: 12),
          Container(width: 1, height: 12, color: _line),
          const SizedBox(width: 12),
          if (profile != null) ...[
            Text(
              '${profile!.username}@${profile!.host}',
              style: _mono(size: 11.5, color: _ink1),
            ),
            if (profile!.jumpHost.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text('↳ via ${profile!.jumpHost}', style: _mono(size: 11.5, color: _acc)),
            ],
          ] else
            Text(tab.profileName, style: _mono(size: 11.5, color: _ink1)),
          const Spacer(),
          _IconBtn(icon: Icons.copy_outlined, tooltip: 'Copy', onTap: () => onCopy(), iconSize: 13),
          _IconBtn(icon: Icons.content_paste_outlined, tooltip: 'Paste', onTap: () => onPaste(), iconSize: 13),
          _IconBtn(icon: Icons.replay_outlined, tooltip: 'Reconnect', onTap: () => onReconnect(), iconSize: 13),
        ],
      ),
    );
  }
}

class _SessionFooter extends StatelessWidget {
  const _SessionFooter({required this.tab, required this.profile});
  final _SessionTab? tab;
  final rust.Profile? profile;

  @override
  Widget build(BuildContext context) {
    final connected = tab?.state == _ConnState.connected;
    final snap = tab?.snapshot;
    final transport = profile == null
        ? (tab?.profileId == _localShellProfileId ? 'PTY' : '—')
        : (profile!.transport.isEmpty ? 'SSH' : profile!.transport.toUpperCase());
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: _bg1,
        border: Border(top: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (connected)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: _Pal.cEmerald, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('$transport · 256/256', style: _mono(size: 11, color: _Pal.cEmerald)),
              ],
            )
          else
            Text(transport, style: _mono(size: 11, color: _ink3)),
          if (profile != null) ...[
            _footSep(),
            Text('${profile!.username}@${profile!.host}:${profile!.port}', style: _mono(size: 11, color: _ink2)),
          ],
          if (tab != null) ...[
            _footSep(),
            Text('started ${_fmtTime(tab!.startedAt)}', style: _mono(size: 11, color: _ink3)),
          ],
          const Spacer(),
          Text('UTF-8', style: _mono(size: 11, color: _ink3)),
          _footSep(),
          Text('${appSettings.value.fontFamily} · ${appSettings.value.fontSize.toStringAsFixed(0)}',
              style: _mono(size: 11, color: _ink3)),
          if (snap != null) ...[
            _footSep(),
            Text('${snap.cols}×${snap.rows}', style: _mono(size: 11, color: _ink3)),
          ],
        ],
      ),
    );
  }

  Widget _footSep() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('·', style: _mono(size: 11, color: _ink3.withValues(alpha: 0.5))),
      );

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ============================================================================
// Cell grid — terminal renderer
// ============================================================================

class _CellGrid extends StatelessWidget {
  const _CellGrid({
    required this.tab,
    required this.isFocused,
    required this.charWidth,
    required this.lineHeight,
  });

  final _SessionTab tab;
  final bool isFocused;
  final double charWidth;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    if (tab.state == _ConnState.connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 1.6, color: _Pal.cAmber)),
            const SizedBox(height: 14),
            Text('Connecting to ${tab.profileName}', style: _mono(size: 12, color: _ink2)),
          ],
        ),
      );
    }
    if (tab.state == _ConnState.disconnected && tab.snapshot == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 28, color: _Pal.cRose),
            const SizedBox(height: 10),
            Text('Disconnected', style: _mono(size: 12, color: _ink2)),
          ],
        ),
      );
    }
    final s = tab.snapshot;
    if (s == null) {
      return Center(child: Text('Waiting for first chunk…', style: _mono(size: 12, color: _ink2)));
    }
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
        if (s.cursorVisible && tab.state == _ConnState.connected)
          Positioned(
            left: s.cursorCol * charWidth,
            top: s.cursorRow * lineHeight,
            width: charWidth,
            height: lineHeight,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: isFocused ? _tFg.withValues(alpha: 0.85) : _tFg.withValues(alpha: 0.20),
                  border: isFocused
                      ? null
                      : Border.all(color: _tFg.withValues(alpha: 0.6), width: 1),
                ),
              ),
            ),
          ),
        if (tab.state == _ConnState.disconnected)
          Positioned(
            top: 6, right: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _Pal.cRose.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('OFFLINE', style: _mono(size: 10, color: Colors.white, weight: FontWeight.w700, letterSpacing: 1.4)),
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
  Color fg = c.fg.default_ ? _tFg : Color.fromARGB(255, c.fg.r, c.fg.g, c.fg.b);
  Color? bg = c.bg.default_ ? null : Color.fromARGB(255, c.bg.r, c.bg.g, c.bg.b);
  if (inverse) {
    final tmpFg = fg;
    fg = bg ?? _tBg;
    bg = tmpFg;
  }
  final base = _termStyle;
  return base.copyWith(
    color: fg,
    backgroundColor: bg,
    fontWeight: (c.attrs & 1) != 0 ? FontWeight.bold : null,
    fontStyle: (c.attrs & 2) != 0 ? FontStyle.italic : null,
    decoration: (c.attrs & 4) != 0 ? TextDecoration.underline : null,
    inherit: true,
  );
}

// ============================================================================
// Generic view chrome — view header, block header, chips, buttons.
// ============================================================================

class _ViewHead extends StatelessWidget {
  const _ViewHead({
    required this.eyebrow,
    required this.title,
    required this.lede,
    this.actions = const [],
  });
  final String eyebrow;
  final String title;
  final String lede;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(), style: _eyebrow()),
                const SizedBox(height: 6),
                Text(title, style: _display(size: 36, weight: FontWeight.w500, color: _ink0)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Text(lede, style: _sans(size: 13.5, color: _ink2)),
                ),
              ],
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                actions[i],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BlockHead extends StatelessWidget {
  const _BlockHead({required this.title, this.sub, this.tools});
  final String title;
  final String? sub;
  final dynamic tools; // String? or List<Widget>?

  @override
  Widget build(BuildContext context) {
    Widget? right;
    if (tools is String) right = Text(tools as String, style: _blockSub());
    if (tools is List<Widget>) {
      right = Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < (tools as List).length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          (tools as List)[i] as Widget,
        ],
      ]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(title.toUpperCase(), style: _blockHead()),
            const Spacer(),
            if (sub != null) Text(sub!, style: _blockSub()),
            ?right,
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.on;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: on ? _accSoft : (_hover ? _bg2 : Colors.transparent),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.label,
            style: _mono(
              size: 11,
              color: on ? _acc : (_hover ? _ink1 : _ink2),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final fg = _isLight ? Colors.white : _Pal.dBg0;
    final bg = _hover ? _ink1 : _ink0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: _sans(size: 13, color: fg, weight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  const _GhostButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final color = _hover ? _ink0 : _ink1;
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _hover ? _bg2 : null,
            border: Border.all(color: _hover ? _line2 : _line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: _sans(size: 13, color: color, weight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyButton extends StatefulWidget {
  const _TinyButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  State<_TinyButton> createState() => _TinyButtonState();
}

class _TinyButtonState extends State<_TinyButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hover ? _bg3 : _bg2,
            border: Border.all(color: _hover ? _line2 : _line),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 11, color: _ink1),
              const SizedBox(width: 4),
              Text(widget.label, style: _sans(size: 11.5, color: _ink1, weight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostLink extends StatefulWidget {
  const _GhostLink({required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  @override
  State<_GhostLink> createState() => _GhostLinkState();
}

class _GhostLinkState extends State<_GhostLink> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.danger
        ? (_hover ? _Pal.cRose : _ink2)
        : (_hover ? _ink0 : _ink2);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _hover ? _bg2 : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(widget.label, style: _mono(size: 11, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Profile card (home view)
// ============================================================================

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    required this.profile,
    required this.selected,
    required this.dense,
    required this.onSelect,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final rust.Profile profile;
  final bool selected;
  final bool dense;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final accent = _accentForProfile(p);
    final tags = p.notes
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        onDoubleTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(widget.dense ? 12 : 16),
          decoration: BoxDecoration(
            color: _hover ? _bg2 : _bg1,
            border: Border.all(color: _hover ? _line2 : _line),
            borderRadius: BorderRadius.circular(10),
          ),
          transform: _hover
              ? (Matrix4.identity()..translateByDouble(0.0, -1.0, 0.0, 1.0))
              : Matrix4.identity(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _BarMark(accent: accent),
                  const Spacer(),
                  _StatusPill(connected: false),
                ],
              ),
              SizedBox(height: widget.dense ? 4 : 8),
              Text(
                p.name.isEmpty ? '(unnamed)' : p.name,
                style: widget.dense
                    ? _sans(size: 15.5, weight: FontWeight.w600, color: _ink0)
                    : _display(size: 18, weight: FontWeight.w500, color: _ink0, letterSpacing: -0.2),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: p.username, style: _mono(size: 11.5, color: _ink1)),
                          TextSpan(text: '@', style: _mono(size: 11.5, color: _ink3)),
                          TextSpan(text: p.host, style: _mono(size: 11.5, color: _ink1)),
                          if (p.port != 22 && p.port != 0)
                            TextSpan(text: ':${p.port}', style: _mono(size: 11.5, color: _acc)),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    (p.transport.isEmpty ? 'ssh' : p.transport).toUpperCase(),
                    style: _mono(size: 10.5, color: _ink2, letterSpacing: 1.0),
                  ),
                  Text(' · ', style: _mono(size: 10.5, color: _ink3)),
                  Text(
                    p.authMethod.isEmpty ? 'key' : p.authMethod,
                    style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.0),
                  ),
                  if (p.jumpHost.isNotEmpty) ...[
                    Text(' · ', style: _mono(size: 10.5, color: _ink3)),
                    Flexible(
                      child: Text(
                        'via ${p.jumpHost}',
                        style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.0),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: widget.dense ? 8 : 12),
              Container(height: 1, color: _line),
              SizedBox(height: widget.dense ? 6 : 10),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final t in tags.take(3)) _Tag(t),
                        if (tags.length > 3) _Tag('+${tags.length - 3}'),
                      ],
                    ),
                  ),
                  if (widget.selected)
                    Tooltip(
                      message: 'Open ${p.name}',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onOpen,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _acc,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'OPEN',
                            style: _mono(
                              size: 10,
                              weight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: _isLight ? Colors.white : _Pal.dBg0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _accentForProfile(rust.Profile p) {
  // Stable accent rotation by id hash so each card feels distinct.
  const palette = [_Pal.cRose, _Pal.cAmber, _Pal.cEmerald, _Pal.cSky, _Pal.cViolet];
  final h = p.id.hashCode.abs();
  return palette[h % palette.length];
}

class _BarMark extends StatelessWidget {
  const _BarMark({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) {
    Widget bar(double height, double opacity) => Container(
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(1),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        bar(14, 0.9),
        const SizedBox(width: 2),
        bar(9, 0.55),
        const SizedBox(width: 2),
        bar(5, 0.35),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connected});
  final bool connected;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            color: connected ? _Pal.cEmerald : _ink3,
            shape: BoxShape.circle,
            boxShadow: connected
                ? [BoxShadow(color: _Pal.cEmerald.withValues(alpha: 0.22), blurRadius: 0, spreadRadius: 3)]
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          connected ? 'LIVE' : 'IDLE',
          style: _mono(
            size: 10,
            color: connected ? _Pal.cEmerald : _ink3,
            letterSpacing: 1.4,
            weight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: _bg3,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: _mono(size: 10, color: _ink2, letterSpacing: 0.4)),
    );
  }
}

// ============================================================================
// Profiles table
// ============================================================================

class _ProfilesTable extends StatelessWidget {
  const _ProfilesTable({
    required this.profiles,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final List<rust.Profile> profiles;
  final ValueChanged<rust.Profile> onOpen;
  final ValueChanged<rust.Profile> onEdit;
  final ValueChanged<rust.Profile> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg1,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _profHead(),
          for (var i = 0; i < profiles.length; i++)
            _ProfileRow(
              profile: profiles[i],
              last: i == profiles.length - 1,
              onOpen: () => onOpen(profiles[i]),
              onEdit: () => onEdit(profiles[i]),
              onDelete: () => onDelete(profiles[i]),
            ),
        ],
      ),
    );
  }

  Widget _profHead() {
    Widget cell(String s) => Text(s.toUpperCase(),
        style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.5));
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: _bg1,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Expanded(flex: 16, child: cell('name')),
          Expanded(flex: 16, child: cell('host')),
          Expanded(flex: 7, child: cell('auth')),
          Expanded(flex: 11, child: cell('tags')),
          Expanded(flex: 9, child: cell('last')),
          const SizedBox(width: 110),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatefulWidget {
  const _ProfileRow({
    required this.profile,
    required this.last,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final rust.Profile profile;
  final bool last;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ProfileRow> createState() => _ProfileRowState();
}

class _ProfileRowState extends State<_ProfileRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final accent = _accentForProfile(p);
    final tags = p.notes
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
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
            Expanded(
              flex: 16,
              child: Row(
                children: [
                  Container(
                    width: 4, height: 16,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      p.name.isEmpty ? '(unnamed)' : p.name,
                      style: _display(size: 15.5, weight: FontWeight.w500, color: _ink0, letterSpacing: -0.2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 16,
              child: Text(
                '${p.username}@${p.host}${p.port != 22 && p.port != 0 ? ':${p.port}' : ''}',
                style: _mono(size: 12, color: _ink1),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 7,
              child: Text(
                (p.authMethod.isEmpty ? 'key' : p.authMethod).toUpperCase(),
                style: _mono(size: 11, color: _ink2, letterSpacing: 1.0),
              ),
            ),
            Expanded(
              flex: 11,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [for (final t in tags.take(3)) _Tag(t)],
              ),
            ),
            Expanded(
              flex: 9,
              child: Text('—', style: _mono(size: 11, color: _ink3)),
            ),
            SizedBox(
              width: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _TinyButton(icon: Icons.play_arrow_rounded, label: 'open', onTap: widget.onOpen),
                  const SizedBox(width: 4),
                  _IconBtn(icon: Icons.edit_outlined, onTap: widget.onEdit, iconSize: 13),
                  _IconBtn(icon: Icons.delete_outline, onTap: widget.onDelete, iconSize: 13, danger: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  String? _error;
  bool _busy = false;

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
    super.dispose();
  }

  rust.Profile? get _profile => widget.profiles.where((p) => p.id == _selProfileId).firstOrNull;

  Future<void> _connect() async {
    final p = _profile;
    if (p == null) return;
    setState(() => _busy = true);
    try {
      final id = _sessionId;
      if (id != null) {
        await rust.sftpClose(sessionId: id);
      }
      final jump = rust.JumpHost(
        host: p.jumpHost,
        port: p.jumpPort == 0 ? 22 : p.jumpPort,
        username: p.jumpUsername,
        privateKeyPath: p.jumpPrivateKeyPath,
        passphrase: null,
      );
      final sid = p.authMethod == 'agent'
          ? await rust.openSftpAgent(host: p.host, port: p.port, username: p.username, jump: jump)
          : await rust.openSftpPubkey(
              host: p.host, port: p.port, username: p.username,
              privateKeyPath: p.privateKeyPath, passphrase: null, jump: jump,
            );
      _sessionId = sid;
      _remotePath = await rust.sftpHome(sessionId: sid);
      await _refresh();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      _remotePath = _remotePath.endsWith('/') ? '$_remotePath${e.name}' : '$_remotePath/${e.name}';
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final segs = _remotePath.split('/').where((s) => s.isNotEmpty).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ViewHead(
            eyebrow: 'files · sftp',
            title: 'Browse remote',
            lede: 'Drag in to upload, drag out to download. Transfers queue on the right.',
            actions: [
              if (widget.profiles.where((p) => p.transport == 'ssh').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
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
                tooltip: 'Up',
                onTap: () {
                  final entry = _remoteEntries.firstWhere(
                    (e) => e.name == '..',
                    orElse: () => rust.SftpEntry(
                      name: '..', isDir: true, isSymlink: false,
                      size: BigInt.zero, mtime: BigInt.zero, permissions: 0,
                    ),
                  );
                  _navigate(entry);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.4, color: _acc)),
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
          Expanded(child: Text(e, style: _mono(size: 11.5, color: _Pal.cRose))),
          _IconBtn(icon: Icons.close, iconSize: 13, onTap: () => setState(() => _error = null)),
        ],
      ),
    );
  }

  Widget _filesTable() {
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
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
            child: Row(
              children: [
                Expanded(flex: 5, child: Text('NAME', style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.5))),
                SizedBox(width: 90, child: Text('SIZE', textAlign: TextAlign.right, style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.5))),
                const SizedBox(width: 16),
                SizedBox(width: 150, child: Text('MODIFIED', textAlign: TextAlign.right, style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.5))),
              ],
            ),
          ),
          if (_sessionId == null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  widget.profiles.where((p) => p.transport == 'ssh').isEmpty
                      ? 'Add an SSH profile to browse files.'
                      : 'Connecting…',
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
              ),
        ],
      ),
    );
  }

  Widget _transfersPanel() {
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
              Text('TRANSFERS', style: _mono(size: 11, color: _ink1, letterSpacing: 1.6, weight: FontWeight.w500)),
              const Spacer(),
              Text('idle', style: _mono(size: 11, color: _ink3)),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: _line),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                Icon(Icons.cloud_done_outlined, size: 20, color: _ink3),
                const SizedBox(height: 6),
                Text('No transfers in flight', style: _mono(size: 11, color: _ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SftpRow extends StatefulWidget {
  const _SftpRow({required this.entry, required this.last, required this.onTap});
  final rust.SftpEntry entry;
  final bool last;
  final VoidCallback onTap;
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
              bottom: BorderSide(color: widget.last ? Colors.transparent : _line),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12, height: 12,
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
    if (n < 1024 * 1024 * 1024) return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(n / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _fmtMtime(BigInt mt) {
    final ms = mt.toInt();
    if (ms <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms * 1000).toLocal();
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

// ============================================================================
// Forwards view
// ============================================================================

class _ForwardsView extends StatefulWidget {
  const _ForwardsView({required this.profiles, required this.selectedProfile});
  final List<rust.Profile> profiles;
  final rust.Profile? selectedProfile;
  @override
  State<_ForwardsView> createState() => _ForwardsViewState();
}

class _ForwardsViewState extends State<_ForwardsView> {
  List<rust.PortForward> _forwards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final list = await rust.listForwards();
      setState(() {
        _forwards = list;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _stop(rust.PortForward f) async {
    await rust.stopForward(id: f.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ViewHead(
            eyebrow: 'network · port forwards',
            title: 'Forwards',
            lede: 'Local (L) tunnels listen on your machine. Remote (R) listens on the host. Dynamic (D) is SOCKS.',
            actions: [
              _GhostButton(icon: Icons.refresh, label: 'Refresh', onTap: _refresh),
              _PrimaryButton(
                icon: Icons.add,
                label: 'New forward',
                onTap: widget.selectedProfile == null ? null : () => _openNewDialog(widget.selectedProfile!),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.6, color: _acc))),
            )
          else if (_forwards.isEmpty)
            Container(
              padding: const EdgeInsets.all(60),
              decoration: BoxDecoration(
                color: _bg1,
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cable_outlined, size: 28, color: _ink3),
                  const SizedBox(height: 10),
                  Text('No active tunnels', style: _display(size: 22, color: _ink0, weight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(
                    widget.selectedProfile == null
                        ? 'Pick a profile, then create a forward.'
                        : 'Open a local forward to ${widget.selectedProfile!.name} to get started.',
                    style: _sans(size: 13, color: _ink2),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final f in _forwards)
                  SizedBox(
                    width: 420,
                    child: _ForwardCard(forward: f, onStop: () => _stop(f)),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openNewDialog(rust.Profile p) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ForwardDialog(profile: p, onCreated: _refresh),
    );
  }
}

class _ForwardCard extends StatelessWidget {
  const _ForwardCard({required this.forward, required this.onStop});
  final rust.PortForward forward;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    const type = 'L';
    final typeColor = _Pal.cEmerald;
    return Container(
      padding: const EdgeInsets.all(16),
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
            children: [
              Container(
                width: 28, height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color.lerp(typeColor, _bg2, 0.84),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(type, style: _mono(size: 11, color: typeColor, weight: FontWeight.w700, letterSpacing: 0.4)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${forward.localAddr}:${forward.localPort}',
                  style: _display(size: 16, weight: FontWeight.w500, color: _ink0, letterSpacing: -0.05),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: _Pal.cEmerald, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _Pal.cEmerald.withValues(alpha: 0.2), blurRadius: 0, spreadRadius: 3)],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('OPEN', style: _mono(size: 10.5, color: _Pal.cEmerald, letterSpacing: 1.2, weight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: _bg2,
              border: Border.all(color: _line2, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _endpoint('LOCAL', '${forward.localAddr}:${forward.localPort}'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text('→', style: _mono(size: 16, color: _acc)),
                      Text('via', style: _mono(size: 10, color: _ink3, letterSpacing: 1.0)),
                    ],
                  ),
                ),
                Expanded(
                  child: _endpoint('REMOTE', '${forward.remoteHost}:${forward.remotePort}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _line),
          const SizedBox(height: 10),
          Row(
            children: [
              _GhostLink(icon: Icons.replay_outlined, label: 'reconnect', onTap: () {}),
              const SizedBox(width: 6),
              _GhostLink(icon: Icons.delete_outline, label: 'drop', onTap: onStop, danger: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _endpoint(String tag, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tag, style: _mono(size: 10, color: _ink3, letterSpacing: 1.3)),
        const SizedBox(height: 2),
        Text(value, style: _mono(size: 12, color: _ink0), overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _ForwardDialog extends StatefulWidget {
  const _ForwardDialog({required this.profile, required this.onCreated});
  final rust.Profile profile;
  final VoidCallback onCreated;
  @override
  State<_ForwardDialog> createState() => _ForwardDialogState();
}

class _ForwardDialogState extends State<_ForwardDialog> {
  final _localAddr = TextEditingController(text: '127.0.0.1');
  final _localPort = TextEditingController(text: '0');
  final _remoteHost = TextEditingController();
  final _remotePort = TextEditingController(text: '22');
  bool _busy = false;
  String? _error;

  Future<void> _open() async {
    final p = widget.profile;
    setState(() { _busy = true; _error = null; });
    try {
      final jump = rust.JumpHost(
        host: p.jumpHost,
        port: p.jumpPort == 0 ? 22 : p.jumpPort,
        username: p.jumpUsername,
        privateKeyPath: p.jumpPrivateKeyPath,
        passphrase: null,
      );
      final lp = int.tryParse(_localPort.text.trim()) ?? 0;
      final rp = int.tryParse(_remotePort.text.trim()) ?? 22;
      if (p.authMethod == 'agent') {
        await rust.openLocalForwardAgent(
          host: p.host, port: p.port, username: p.username, jump: jump,
          localAddr: _localAddr.text.trim(), localPort: lp,
          remoteHost: _remoteHost.text.trim(), remotePort: rp,
        );
      } else {
        await rust.openLocalForwardPubkey(
          host: p.host, port: p.port, username: p.username,
          privateKeyPath: p.privateKeyPath, passphrase: null, jump: jump,
          localAddr: _localAddr.text.trim(), localPort: lp,
          remoteHost: _remoteHost.text.trim(), remotePort: rp,
        );
      }
      if (mounted) {
        widget.onCreated();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _line2)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('NEW FORWARD', style: _eyebrow()),
                const Spacer(),
                _IconBtn(icon: Icons.close, onTap: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Local forward', style: _display(size: 22, weight: FontWeight.w500, color: _ink0)),
            const SizedBox(height: 4),
            Text('A listener on your machine that tunnels through ${widget.profile.name}.',
                style: _sans(size: 12.5, color: _ink2)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _fwdField('LOCAL ADDR', _localAddr, '127.0.0.1')),
              const SizedBox(width: 8),
              SizedBox(width: 100, child: _fwdField('PORT', _localPort, '0')),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(child: Icon(Icons.arrow_downward, size: 14, color: _acc)),
            ),
            Row(children: [
              Expanded(child: _fwdField('REMOTE HOST', _remoteHost, 'cache.svc')),
              const SizedBox(width: 8),
              SizedBox(width: 100, child: _fwdField('PORT', _remotePort, '6379')),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: _mono(size: 11.5, color: _Pal.cRose)),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _GhostButton(icon: Icons.close, label: 'CANCEL', onTap: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                _PrimaryButton(icon: Icons.bolt, label: 'OPEN', onTap: _busy ? null : _open),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fwdField(String label, TextEditingController c, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(label, style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.3)),
          ),
          TextField(
            controller: c,
            decoration: InputDecoration(hintText: hint, isDense: true),
            style: _mono(size: 12.5, color: _ink0),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Host keys view
// ============================================================================

class _KeysView extends StatefulWidget {
  const _KeysView();
  @override
  State<_KeysView> createState() => _KeysViewState();
}

class _KeysViewState extends State<_KeysView> {
  late Future<List<rust.HostKey>> _future;

  @override
  void initState() {
    super.initState();
    _future = rust.listHostKeys();
  }

  void _reload() {
    setState(() => _future = rust.listHostKeys());
  }

  String _fmt(BigInt ms) {
    final n = ms.toInt();
    if (n <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(n).toLocal();
    return dt.toString().substring(0, 16);
  }

  Future<void> _delete(rust.HostKey k) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.removeTrustedHostKeyQuestion),
          content: Text(l10n.removeTrustedHostKeyContent(k.host, k.port)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _Pal.cRose),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.remove),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await rust.deleteHostKey(host: k.host, port: k.port);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ViewHead(
            eyebrow: 'trust · host keys',
            title: 'Trusted host keys',
            lede: 'Trust-on-first-use. Tindra remembers the first key seen for each host and refuses connections when the key changes.',
            actions: [
              _GhostButton(icon: Icons.refresh, label: 'Refresh', onTap: _reload),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<rust.HostKey>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.6, color: _acc))),
                );
              }
              if (snap.hasError) {
                return _errBox(snap.error.toString());
              }
              final keys = snap.data ?? const [];
              if (keys.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(60),
                  decoration: BoxDecoration(
                    color: _bg1,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.vpn_key_outlined, size: 26, color: _ink3),
                      const SizedBox(height: 10),
                      Text('No trusted keys yet', style: _display(size: 22, color: _ink0, weight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('Connect to a host once and Tindra will remember it.', style: _sans(size: 12.5, color: _ink2)),
                    ],
                  ),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  color: _bg1,
                  border: Border.all(color: _line),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < keys.length; i++) _keyRow(keys[i], i == keys.length - 1, _fmt),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _keyRow(rust.HostKey k, bool last, String Function(BigInt) fmt) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: last ? Colors.transparent : _line))),
      child: Row(
        children: [
          Container(width: 6, height: 18, decoration: BoxDecoration(color: _Pal.cEmerald, borderRadius: BorderRadius.circular(1))),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text('${k.host}:${k.port}', style: _mono(size: 12.5, color: _ink0)),
          ),
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Text('SSH-ED25519', style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.0)),
                const SizedBox(width: 10),
                Flexible(child: Text(k.fingerprint, style: _mono(size: 11.5, color: _ink1), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Text('first ${fmt(k.firstSeenUnixMs)}', style: _mono(size: 10.5, color: _ink3)),
                const SizedBox(width: 10),
                Text('last ${fmt(k.lastSeenUnixMs)}', style: _mono(size: 10.5, color: _ink3)),
              ],
            ),
          ),
          _IconBtn(icon: Icons.delete_outline, iconSize: 14, danger: true, onTap: () => _delete(k)),
        ],
      ),
    );
  }

  Widget _errBox(String e) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isLight ? const Color(0xFFFCEDE9) : const Color(0xFF2A1417),
          border: Border.all(color: _Pal.cRose),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(e, style: _mono(size: 12, color: _Pal.cRose)),
      );
}

// ============================================================================
// Settings view
// ============================================================================

class _SettingsView extends StatefulWidget {
  const _SettingsView({required this.onSave});
  final Future<void> Function(rust.Settings) onSave;
  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  late String _theme;
  late String _accent;
  late bool _dense;
  late String _font;
  late double _size;
  late String _quake;
  late String _locale;

  @override
  void initState() {
    super.initState();
    final s = appSettings.value;
    _theme = s.theme.isEmpty ? 'dark' : s.theme;
    _accent = appAccent.value;
    _dense = appDense.value;
    _font = s.fontFamily.isEmpty ? 'JetBrains Mono' : s.fontFamily;
    _size = s.fontSize > 0 ? s.fontSize : 13.0;
    _quake = s.quakeHotkey;
    _locale = s.locale.isEmpty ? 'system' : s.locale;
  }

  Future<void> _commit() async {
    appAccent.value = _accent;
    appDense.value = _dense;
    await widget.onSave(rust.Settings(
      theme: _theme,
      fontFamily: _font.trim().isEmpty ? 'JetBrains Mono' : _font.trim(),
      fontSize: _size,
      quakeHotkey: _quake.trim(),
      locale: _locale,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ViewHead(
            eyebrow: 'preferences',
            title: 'Settings',
            lede: 'Theme, accent and density apply immediately. Other changes save when you click Apply.',
            actions: [
              _PrimaryButton(icon: Icons.check, label: 'APPLY', onTap: _commit),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 1100 ? 3 : 1;
            final groups = [
              _appearanceGroup(),
              _terminalGroup(),
              _syncGroup(l10n),
            ];
            return Wrap(
              spacing: 16, runSpacing: 16,
              children: [
                for (final g in groups)
                  SizedBox(
                    width: cols == 1 ? c.maxWidth : (c.maxWidth - (cols - 1) * 16) / cols,
                    child: g,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _appearanceGroup() {
    return _SGroup(
      title: 'Appearance',
      children: [
        _SRow(
          label: 'Theme',
          hint: 'OLED-friendly dark, paper light, or stay on the system default',
          child: _Seg<String>(
            value: _theme,
            options: const [('dark', 'DARK'), ('light', 'LIGHT')],
            onChanged: (v) {
              setState(() => _theme = v);
              appSettings.value = rust.Settings(
                theme: v, fontFamily: _font, fontSize: _size,
                quakeHotkey: _quake, locale: _locale,
              );
            },
          ),
        ),
        _SRow(
          label: 'Accent',
          hint: 'Used for live indicators, focus, and highlights',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in const ['rose', 'amber', 'emerald', 'sky', 'violet'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Swatch(
                    color: colorForAccent(a),
                    selected: _accent == a,
                    onTap: () {
                      setState(() => _accent = a);
                      appAccent.value = a;
                    },
                  ),
                ),
            ],
          ),
        ),
        _SRow(
          label: 'Density',
          hint: 'Tighter rows fit more on a smaller screen',
          child: _Seg<bool>(
            value: _dense,
            options: const [(false, 'COZY'), (true, 'COMPACT')],
            onChanged: (v) {
              setState(() => _dense = v);
              appDense.value = v;
            },
          ),
        ),
      ],
    );
  }

  Widget _terminalGroup() {
    return _SGroup(
      title: 'Terminal',
      children: [
        _SRow(
          label: 'Font',
          hint: 'JetBrains Mono is bundled. Falls back to Cascadia Mono / Consolas.',
          child: _Seg<String>(
            value: _font,
            options: const [
              ('JetBrains Mono', 'JETBRAINS'),
              ('Cascadia Mono', 'CASCADIA'),
              ('Consolas', 'CONSOLAS'),
            ],
            onChanged: (v) => setState(() => _font = v),
          ),
        ),
        _SRow(
          label: 'Size',
          hint: '${_size.toStringAsFixed(0)} pt',
          child: SizedBox(
            width: 220,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _acc,
                inactiveTrackColor: _line2,
                thumbColor: _acc,
                overlayColor: _acc.withValues(alpha: 0.12),
              ),
              child: Slider(
                value: _size, min: 9, max: 24, divisions: 15,
                onChanged: (v) => setState(() => _size = v),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _syncGroup(AppLocalizations l10n) {
    return _SGroup(
      title: 'Sync · system',
      children: [
        _SRow(
          label: 'Quake hotkey',
          hint: 'Global key to summon Tindra over any window',
          child: SizedBox(
            width: 180,
            child: TextField(
              controller: TextEditingController(text: _quake),
              onChanged: (v) => _quake = v,
              decoration: const InputDecoration(hintText: 'F12', isDense: true),
              style: _mono(size: 12.5, color: _ink0),
            ),
          ),
        ),
        _SRow(
          label: 'Language',
          hint: l10n.language,
          child: _Seg<String>(
            value: _locale,
            options: const [
              ('system', 'SYSTEM'),
              ('en', 'EN'),
              ('ko', 'KO'),
            ],
            onChanged: (v) => setState(() => _locale = v),
          ),
        ),
      ],
    );
  }
}

class _SGroup extends StatelessWidget {
  const _SGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _bg1,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
              child: Text(
                title.toUpperCase(),
                style: _mono(size: 11, color: _ink2, letterSpacing: 1.6, weight: FontWeight.w500),
              ),
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _SRow extends StatelessWidget {
  const _SRow({required this.label, this.hint, required this.child});
  final String label;
  final String? hint;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _sans(size: 13.5, color: _ink0, weight: FontWeight.w500)),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, style: _sans(size: 12, color: _ink2)),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _Seg<T> extends StatelessWidget {
  const _Seg({required this.value, required this.options, required this.onChanged});
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _bg2,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in options)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: v == value ? _bg0 : null,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: v == value ? [BoxShadow(color: _line2, blurRadius: 0, spreadRadius: 1)] : null,
                ),
                child: Text(
                  label,
                  style: _mono(size: 11, color: v == value ? _ink0 : _ink2, letterSpacing: 0.5, weight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? _ink0 : Colors.transparent, width: 2),
        ),
      ),
    );
  }
}

// ============================================================================
// Profile dialog (real implementation)
// ============================================================================

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
  late final TextEditingController _jumpHost;
  late final TextEditingController _jumpPort;
  late final TextEditingController _jumpUser;
  late final TextEditingController _jumpKey;
  late String _authMethod;
  late bool _showJump;
  late String _transport;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _host = TextEditingController(text: p?.host ?? '');
    _port = TextEditingController(text: (p?.port ?? 22).toString());
    _user = TextEditingController(text: p?.username ?? '');
    _key = TextEditingController(text: p?.privateKeyPath ?? r'C:\Users\XIU\.ssh\id_ed25519');
    _notes = TextEditingController(text: p?.notes ?? '');
    _jumpHost = TextEditingController(text: p?.jumpHost ?? '');
    _jumpPort = TextEditingController(text: ((p?.jumpPort ?? 0) == 0 ? 22 : p!.jumpPort).toString());
    _jumpUser = TextEditingController(text: p?.jumpUsername ?? '');
    _jumpKey = TextEditingController(text: p?.jumpPrivateKeyPath ?? '');
    _authMethod = (p?.authMethod.isEmpty ?? true) ? 'key' : p!.authMethod;
    _showJump = (p?.jumpHost.isNotEmpty ?? false);
    _transport = (p?.transport.isEmpty ?? true) ? 'ssh' : p!.transport;
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _user, _key, _notes, _jumpHost, _jumpPort, _jumpUser, _jumpKey]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final port = int.tryParse(_port.text.trim()) ?? 22;
    final jumpPort = int.tryParse(_jumpPort.text.trim()) ?? 22;
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
      authMethod: _authMethod,
      jumpHost: _showJump ? _jumpHost.text.trim() : '',
      jumpPort: jumpPort,
      jumpUsername: _showJump ? _jumpUser.text.trim() : '',
      jumpPrivateKeyPath: _showJump ? _jumpKey.text.trim() : '',
      transport: _transport,
    );
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: _bg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _line2),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(isNew ? 'NEW PROFILE' : 'EDIT PROFILE', style: _eyebrow()),
                const Spacer(),
                _IconBtn(icon: Icons.close, onTap: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isNew ? 'A new connection' : _name.text,
              style: _display(size: 24, weight: FontWeight.w500, color: _ink0),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _row(l10n.name, _name, hint: 'edge-prod-01'),
                    _row(l10n.host, _host, hint: 'localhost / 1.2.3.4 / dev.example.com'),
                    Row(children: [
                      Expanded(child: _row(l10n.user, _user, hint: 'XIU')),
                      const SizedBox(width: 8),
                      SizedBox(width: 100, child: _row(l10n.port, _port)),
                    ]),
                    _segLabel(l10n.transport),
                    _segments(
                      value: _transport,
                      options: [
                        ('ssh', l10n.ssh),
                        ('telnet', l10n.telnetRawTcp),
                      ],
                      onChanged: (v) => setState(() => _transport = v),
                    ),
                    if (_transport == 'ssh') ...[
                      _segLabel(l10n.auth),
                      _segments(
                        value: _authMethod,
                        options: [
                          ('key', l10n.privateKey),
                          ('agent', l10n.sshAgent),
                        ],
                        onChanged: (v) => setState(() => _authMethod = v),
                      ),
                      if (_authMethod == 'key') _row(l10n.privateKeyPath, _key),
                    ],
                    _jumpSection(l10n),
                    _row(l10n.notes, _notes, hint: l10n.optional, maxLines: 2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _GhostButton(icon: Icons.close, label: l10n.cancel.toUpperCase(), onTap: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                _PrimaryButton(
                  icon: isNew ? Icons.add : Icons.check,
                  label: (isNew ? l10n.create : l10n.save).toUpperCase(),
                  onTap: _host.text.trim().isEmpty || _user.text.trim().isEmpty ? null : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segLabel(String label) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
        child: Text(label.toUpperCase(), style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.3)),
      );

  Widget _segments({
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _bg2,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          for (final (val, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(val),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: value == val ? _bg0 : null,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: value == val
                        ? [BoxShadow(color: _line2, blurRadius: 0, spreadRadius: 1)]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label.toUpperCase(),
                    style: _mono(
                      size: 11,
                      color: value == val ? _ink0 : _ink2,
                      letterSpacing: 0.6,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _jumpSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _segLabel(l10n.jumpHost),
              const Spacer(),
              Switch(
                value: _showJump,
                activeThumbColor: _isLight ? Colors.white : _Pal.dBg0,
                activeTrackColor: _acc,
                onChanged: (v) => setState(() => _showJump = v),
              ),
            ],
          ),
          if (_showJump) ...[
            Row(children: [
              Expanded(child: _row(l10n.host, _jumpHost, hint: 'jump.example.com')),
              const SizedBox(width: 8),
              SizedBox(width: 100, child: _row(l10n.port, _jumpPort)),
            ]),
            Row(children: [
              Expanded(child: _row(l10n.user, _jumpUser, hint: 'XIU')),
              const SizedBox(width: 8),
              Expanded(child: _row(l10n.keyPath, _jumpKey)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, TextEditingController c, {String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(label.toUpperCase(),
                style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.3)),
          ),
          TextField(
            controller: c,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: hint, isDense: true),
            style: _mono(size: 12.5, color: _ink0),
          ),
        ],
      ),
    );
  }
}
