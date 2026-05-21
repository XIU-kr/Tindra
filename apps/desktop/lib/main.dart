// SPDX-License-Identifier: Apache-2.0
//
// Tindra desktop ??editorial-tech UI.
//
// Single-file Flutter shell that mirrors the Tindra Redesign prototype:
// 36px title bar with traffic lights, 230px sidebar with six top-level views,
// command palette (Cmd/Ctrl+K), and inline pages for Sessions, Profiles,
// Files (SFTP), Forwards, Host keys and Settings. All Rust FFI session
// management lives unchanged inside `_ShellScreenState` ??only the
// presentation layer was rewritten.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:tindra_desktop/l10n/app_localizations.dart';
import 'package:tindra_desktop/src/session_status.dart';
import 'package:tindra_shared_ui/tindra_shared_ui.dart';
import 'package:tindra_desktop/src/rust/api/forward.dart' as rust;
import 'package:tindra_desktop/src/rust/api/hello.dart' as rust;
import 'package:tindra_desktop/src/rust/api/profiles.dart' as rust;
import 'package:tindra_desktop/src/rust/api/settings.dart' as rust;
import 'package:tindra_desktop/src/rust/api/sftp.dart' as rust;
import 'package:tindra_desktop/src/rust/api/ssh.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

part 'src/ui/typography.dart';
part 'src/ui/design_tokens.dart';
part 'src/ui/intents.dart';
part 'src/ui/shell_chrome.dart';
part 'src/session/session_pane.dart';
part 'src/profiles/profile_views.dart';
part 'src/files/sftp_view.dart';

// ============================================================================
// Startup
// ============================================================================

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.length >= 3 && args[0] == 'multi_window') {
    await windowManager.ensureInitialized();
    await RustLib.init();
    runApp(_DetachedNativeWindowApp(arguments: args[2]));
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Tindra',
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      minimumSize: Size(960, 600),
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
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
    // already taken ??silent fall back
  }
}

LogicalKeyboardKey? _parseHotkey(String s) {
  switch (s.toUpperCase()) {
    case 'F1':
      return LogicalKeyboardKey.f1;
    case 'F2':
      return LogicalKeyboardKey.f2;
    case 'F3':
      return LogicalKeyboardKey.f3;
    case 'F4':
      return LogicalKeyboardKey.f4;
    case 'F5':
      return LogicalKeyboardKey.f5;
    case 'F6':
      return LogicalKeyboardKey.f6;
    case 'F7':
      return LogicalKeyboardKey.f7;
    case 'F8':
      return LogicalKeyboardKey.f8;
    case 'F9':
      return LogicalKeyboardKey.f9;
    case 'F10':
      return LogicalKeyboardKey.f10;
    case 'F11':
      return LogicalKeyboardKey.f11;
    case 'F12':
      return LogicalKeyboardKey.f12;
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
    localShell: '',
    localShellCwd: '',
    localShellEnv: '',
  ),
);

/// User-pickable Nordfjord palette accent.
final ValueNotifier<String> appAccent = ValueNotifier('frost');

/// Compact-density toggle.
final ValueNotifier<bool> appDense = ValueNotifier(false);

const _accentChoices = <(String, String)>[
  ('frost', 'FROST'),
  ('aurora', 'AURORA'),
  ('glacier', 'GLACIER'),
  ('twilight', 'TWILIGHT'),
  ('coal', 'COAL'),
  ('snow', 'SNOW'),
  ('rose', 'ROSE'),
  ('amber', 'AMBER'),
];

enum _TerminalCursorStyle { block, bar, underline }

class _TerminalPrefs {
  const _TerminalPrefs({
    this.cursorStyle = _TerminalCursorStyle.block,
    this.copyOnSelect = false,
    this.scrollbackLimit = 1000,
    this.warnOnLargePaste = true,
  });

  final _TerminalCursorStyle cursorStyle;
  final bool copyOnSelect;
  final int scrollbackLimit;
  final bool warnOnLargePaste;

  Map<String, dynamic> toJson() => {
    'cursorStyle': cursorStyle.name,
    'copyOnSelect': copyOnSelect,
    'scrollbackLimit': scrollbackLimit,
    'warnOnLargePaste': warnOnLargePaste,
  };

  factory _TerminalPrefs.fromJson(Map<String, dynamic>? json) {
    final rawCursor = json?['cursorStyle'] as String?;
    return _TerminalPrefs(
      cursorStyle: _TerminalCursorStyle.values.firstWhere(
        (style) => style.name == rawCursor,
        orElse: () => _TerminalCursorStyle.block,
      ),
      copyOnSelect: json?['copyOnSelect'] == true,
      scrollbackLimit: (json?['scrollbackLimit'] as int? ?? 1000).clamp(
        100,
        10000,
      ),
      warnOnLargePaste: json?['warnOnLargePaste'] != false,
    );
  }

  _TerminalPrefs copyWith({
    _TerminalCursorStyle? cursorStyle,
    bool? copyOnSelect,
    int? scrollbackLimit,
    bool? warnOnLargePaste,
  }) => _TerminalPrefs(
    cursorStyle: cursorStyle ?? this.cursorStyle,
    copyOnSelect: copyOnSelect ?? this.copyOnSelect,
    scrollbackLimit: scrollbackLimit ?? this.scrollbackLimit,
    warnOnLargePaste: warnOnLargePaste ?? this.warnOnLargePaste,
  );
}

// ignore: library_private_types_in_public_api
final ValueNotifier<_TerminalPrefs> terminalPrefs = ValueNotifier(
  const _TerminalPrefs(),
);

const Map<String, String> _defaultShortcutBindings = {
  'newTab': 'Ctrl+T',
  'closeTab': 'Ctrl+W',
  'nextTab': 'Ctrl+Tab',
  'prevTab': 'Ctrl+Shift+Tab',
  'palette': 'Ctrl+K',
  'settings': 'Ctrl+,',
  'splitRight': 'Ctrl+Shift+H',
  'splitDown': 'Ctrl+Shift+E',
  'copy': 'Ctrl+Shift+C',
  'paste': 'Ctrl+Shift+V',
  'reconnect': 'Ctrl+Shift+R',
  'duplicateTab': 'Ctrl+Shift+D',
  'closeOtherTabs': 'None',
  'closeTabsToRight': 'None',
  'prevPane': 'Alt+Left',
  'nextPane': 'Alt+Right',
  'maximizePane': 'Ctrl+Shift+M',
  'moveTabLeft': 'Ctrl+Shift+Left',
  'moveTabRight': 'Ctrl+Shift+Right',
  'detachTab': 'Ctrl+Shift+O',
  'pinTab': 'Ctrl+Shift+P',
  'closePane': 'Ctrl+Shift+W',
};

const Map<String, String> _shortcutLabels = {
  'newTab': 'New tab',
  'closeTab': 'Close tab',
  'nextTab': 'Next tab',
  'prevTab': 'Previous tab',
  'palette': 'Command palette',
  'settings': 'Settings',
  'splitRight': 'Split right',
  'splitDown': 'Split down',
  'copy': 'Copy',
  'paste': 'Paste',
  'reconnect': 'Reconnect',
  'duplicateTab': 'Duplicate tab',
  'closeOtherTabs': 'Close other tabs',
  'closeTabsToRight': 'Close tabs to the right',
  'prevPane': 'Previous pane',
  'nextPane': 'Next pane',
  'maximizePane': 'Maximize pane',
  'moveTabLeft': 'Move tab left',
  'moveTabRight': 'Move tab right',
  'detachTab': 'Detach tab',
  'pinTab': 'Pin tab',
  'closePane': 'Close pane',
};

class _ShortcutPrefs {
  const _ShortcutPrefs({this.bindings = _defaultShortcutBindings});

  final Map<String, String> bindings;

  String bindingFor(String action) =>
      bindings[action] ?? _defaultShortcutBindings[action] ?? 'None';

  Map<String, dynamic> toJson() => {'bindings': bindings};

  factory _ShortcutPrefs.fromJson(Map<String, dynamic>? json) {
    final raw = json?['bindings'] as Map<String, dynamic>? ?? const {};
    return _ShortcutPrefs(
      bindings: {
        ..._defaultShortcutBindings,
        for (final entry in raw.entries)
          if (entry.value is String) entry.key: entry.value as String,
      },
    );
  }
}

// ignore: library_private_types_in_public_api
final ValueNotifier<_ShortcutPrefs> shortcutPrefs = ValueNotifier(
  const _ShortcutPrefs(),
);

// ============================================================================
// Design tokens: Nordfjord palette family from the canvas handoff.
// ============================================================================

class _Pal {
  // Nordfjord Frost
  static const dBg0 = Color(0xFF161A22);
  static const dBg1 = Color(0xFF1C212B);
  static const dBg2 = Color(0xFF232938);
  static const dBg3 = Color(0xFF2B3242);
  static const dLine = Color(0xFF262D3A);
  static const dLine2 = Color(0xFF323A4A);
  static const dInk0 = Color(0xFFE5EAF2);
  static const dInk1 = Color(0xFFAEB8C9);
  static const dInk2 = Color(0xFF7B8699);
  static const dInk3 = Color(0xFF525C70);
  static const dTBg = Color(0xFF11151C);
  static const dTFg = Color(0xFFD8DEE9);

  // Nordfjord Coal
  static const cBg0 = Color(0xFF0A0C11);
  static const cBg1 = Color(0xFF0F1218);
  static const cBg2 = Color(0xFF171A22);
  static const cBg3 = Color(0xFF22262E);
  static const cLine = Color(0xFF1A1E26);
  static const cLine2 = Color(0xFF262B36);
  static const cTBg = Color(0xFF06080C);

  // Nordfjord Snow
  static const lBg0 = Color(0xFFECEFF4);
  static const lBg1 = Color(0xFFE5E9F0);
  static const lBg2 = Color(0xFFD8DEE9);
  static const lBg3 = Color(0xFFC9D0DD);
  static const lLine = Color(0xFFD8DEE9);
  static const lLine2 = Color(0xFFC0C8D6);
  static const lInk0 = Color(0xFF2E3440);
  static const lInk1 = Color(0xFF434C5E);
  static const lInk2 = Color(0xFF5E6776);
  static const lInk3 = Color(0xFF838B98);
  static const lTBg = Color(0xFFF4F6FA);
  static const lTFg = Color(0xFF2E3440);

  // Nordfjord accents
  static const cFrost = Color(0xFF88C0D0);
  static const cAurora = Color(0xFFA3BE8C);
  static const cGlacier = Color(0xFF81A1C1);
  static const cTwilight = Color(0xFFB48EAD);
  static const cCoal = Color(0xFF8FBCBB);
  static const cSnow = Color(0xFF4C7B8C);
  static const cRose = Color(0xFFBF616A);
  static const cAmber = Color(0xFFEBCB8B);
  static const cEmerald = cAurora;
  static const cSky = cFrost;
  static const cViolet = cTwilight;
  static const cSlate = Color(0xFF4C566A);
}

bool get _isLight =>
    appSettings.value.theme == 'light' || appAccent.value == 'snow';
bool get _isCoal => !_isLight && appAccent.value == 'coal';

Color get _bg0 => _isLight ? _Pal.lBg0 : (_isCoal ? _Pal.cBg0 : _Pal.dBg0);
Color get _bg1 => _isLight ? _Pal.lBg1 : (_isCoal ? _Pal.cBg1 : _Pal.dBg1);
Color get _bg2 => _isLight ? _Pal.lBg2 : (_isCoal ? _Pal.cBg2 : _Pal.dBg2);
Color get _bg3 => _isLight ? _Pal.lBg3 : (_isCoal ? _Pal.cBg3 : _Pal.dBg3);
Color get _line => _isLight ? _Pal.lLine : (_isCoal ? _Pal.cLine : _Pal.dLine);
Color get _line2 =>
    _isLight ? _Pal.lLine2 : (_isCoal ? _Pal.cLine2 : _Pal.dLine2);
Color get _ink0 => _isLight ? _Pal.lInk0 : _Pal.dInk0;
Color get _ink1 => _isLight ? _Pal.lInk1 : _Pal.dInk1;
Color get _ink2 => _isLight ? _Pal.lInk2 : _Pal.dInk2;
Color get _ink3 => _isLight ? _Pal.lInk3 : _Pal.dInk3;
Color get _tBg => _isLight ? _Pal.lTBg : (_isCoal ? _Pal.cTBg : _Pal.dTBg);
Color get _tFg => _isLight ? _Pal.lTFg : _Pal.dTFg;

Color colorForAccent(String name) {
  switch (name) {
    case 'frost':
      return _Pal.cFrost;
    case 'aurora':
      return _Pal.cAurora;
    case 'glacier':
      return _Pal.cGlacier;
    case 'twilight':
      return _Pal.cTwilight;
    case 'coal':
      return _Pal.cCoal;
    case 'snow':
      return _Pal.cSnow;
    case 'amber':
      return _Pal.cAmber;
    case 'emerald':
      return _Pal.cEmerald;
    case 'sky':
      return _Pal.cSky;
    case 'violet':
      return _Pal.cViolet;
    case 'slate':
      return _Pal.cSlate;
    case 'rose':
      return _Pal.cRose;
    default:
      return _Pal.cFrost;
  }
}

Color get _acc => colorForAccent(appAccent.value);
Color get _accSoft => _acc.withValues(alpha: 0.18);
Color get _accDeep => Color.lerp(_acc, _Pal.dBg1, 0.4)!;

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
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
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
            textTheme: GoogleFonts.interTextTheme(
              base.textTheme,
            ).apply(bodyColor: _ink0, displayColor: _ink0),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
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
              titleTextStyle: _display(
                size: 22,
                weight: FontWeight.w500,
                color: _ink0,
              ),
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
  _SessionTab({required this.profileId, required this.profileName})
    : displayName = profileName;

  final String profileId;
  final String profileName;
  String displayName;
  Color? tabColor;
  bool pinned = false;

  BigInt? sessionId;
  _ConnState state = _ConnState.connecting;
  rust.TerminalSnapshot? snapshot;
  StreamSubscription<rust.TerminalSnapshot>? outputSub;
  String? error;
  DateTime startedAt = DateTime.now();
  DateTime lastActivityAt = DateTime.now();
  bool hasUnreadActivity = false;
  bool hasBellActivity = false;
  String? selectedTerminalText;

  int cols = 120;
  int rows = 32;
  Timer? resizeDebounce;
  String terminalSearchQuery = '';
  int terminalSearchIndex = 0;
  bool terminalSearchCaseSensitive = false;
  bool terminalSearchWholeWord = false;
  bool terminalSearchRegex = false;

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
  _TabGroup({required this.profileName, required _SessionTab first})
    : sessions = [first],
      splitWeights = [1.0];

  String profileName;
  bool pinned = false;
  Color? tabColor;
  final List<_SessionTab> sessions;
  final List<double> splitWeights;
  Axis splitAxis = Axis.horizontal;
  int activeIdx = 0;
  int? maximizedIdx;

  _SessionTab get active => sessions[activeIdx.clamp(0, sessions.length - 1)];

  String get displayName => active.displayName;

  void normalizeWeights() {
    while (splitWeights.length < sessions.length) {
      splitWeights.add(1.0);
    }
    while (splitWeights.length > sessions.length) {
      splitWeights.removeLast();
    }
    if (maximizedIdx != null &&
        (maximizedIdx! < 0 || maximizedIdx! >= sessions.length)) {
      maximizedIdx = null;
    }
  }

  Future<void> dispose() async {
    for (final s in sessions) {
      await s.dispose();
    }
  }
}

class _DesktopState {
  const _DesktopState({
    this.quickConnectHistory = const [],
    this.quickConnectFavorites = const [],
    this.lastProfileIds = const [],
    this.lastLayoutGroups = const [],
    this.sidebarCollapsed = false,
    this.terminalPrefs = const _TerminalPrefs(),
    this.shortcutPrefs = const _ShortcutPrefs(),
  });

  final List<String> quickConnectHistory;
  final List<String> quickConnectFavorites;
  final List<String> lastProfileIds;
  final List<_SavedLayoutGroup> lastLayoutGroups;
  final bool sidebarCollapsed;
  final _TerminalPrefs terminalPrefs;
  final _ShortcutPrefs shortcutPrefs;

  Map<String, dynamic> toJson() => {
    'quickConnectHistory': quickConnectHistory,
    'quickConnectFavorites': quickConnectFavorites,
    'lastProfileIds': lastProfileIds,
    'lastLayoutGroups': [for (final group in lastLayoutGroups) group.toJson()],
    'sidebarCollapsed': sidebarCollapsed,
    'terminalPrefs': terminalPrefs.toJson(),
    'shortcutPrefs': shortcutPrefs.toJson(),
  };

  factory _DesktopState.fromJson(Map<String, dynamic> json) => _DesktopState(
    quickConnectHistory:
        (json['quickConnectHistory'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
    quickConnectFavorites:
        (json['quickConnectFavorites'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
    lastProfileIds: (json['lastProfileIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    lastLayoutGroups: [
      for (final item
          in (json['lastLayoutGroups'] as List<dynamic>? ?? const []))
        if (item is Map<String, dynamic>) _SavedLayoutGroup.fromJson(item),
    ],
    sidebarCollapsed: json['sidebarCollapsed'] == true,
    terminalPrefs: _TerminalPrefs.fromJson(
      json['terminalPrefs'] as Map<String, dynamic>?,
    ),
    shortcutPrefs: _ShortcutPrefs.fromJson(
      json['shortcutPrefs'] as Map<String, dynamic>?,
    ),
  );
}

class _SavedLayoutGroup {
  const _SavedLayoutGroup({
    required this.profileIds,
    required this.splitAxis,
    required this.splitWeights,
    required this.activeIdx,
    required this.maximizedIdx,
    required this.displayName,
    required this.pinned,
    required this.tabColor,
  });

  final List<String> profileIds;
  final Axis splitAxis;
  final List<double> splitWeights;
  final int activeIdx;
  final int? maximizedIdx;
  final String displayName;
  final bool pinned;
  final Color? tabColor;

  Map<String, dynamic> toJson() => {
    'profileIds': profileIds,
    'splitAxis': splitAxis == Axis.horizontal ? 'horizontal' : 'vertical',
    'splitWeights': splitWeights,
    'activeIdx': activeIdx,
    'maximizedIdx': maximizedIdx,
    'displayName': displayName,
    'pinned': pinned,
    'tabColor': tabColor?.toARGB32(),
  };

  factory _SavedLayoutGroup.fromJson(Map<String, dynamic> json) {
    return _SavedLayoutGroup(
      profileIds: (json['profileIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      splitAxis: json['splitAxis'] == 'vertical'
          ? Axis.vertical
          : Axis.horizontal,
      splitWeights: [
        for (final value
            in (json['splitWeights'] as List<dynamic>? ?? const []))
          if (value is num) value.toDouble(),
      ],
      activeIdx: json['activeIdx'] as int? ?? 0,
      maximizedIdx: json['maximizedIdx'] as int?,
      displayName: json['displayName'] as String? ?? '',
      pinned: json['pinned'] == true,
      tabColor: switch (json['tabColor']) {
        final int value => Color(value),
        _ => null,
      },
    );
  }

  static _SavedLayoutGroup? fromGroup(_TabGroup group) {
    final ids = [
      for (final session in group.sessions)
        if (session.profileId != _localShellProfileId) session.profileId,
    ];
    if (ids.isEmpty) return null;
    return _SavedLayoutGroup(
      profileIds: ids,
      splitAxis: group.splitAxis,
      splitWeights: group.splitWeights.take(ids.length).toList(),
      activeIdx: group.activeIdx.clamp(0, ids.length - 1),
      maximizedIdx: group.maximizedIdx,
      displayName: group.displayName,
      pinned: group.pinned,
      tabColor: group.tabColor,
    );
  }
}

class _TabDragPayload {
  const _TabDragPayload(this.index);
  final int index;
}

class _DetachedTabGroup {
  _DetachedTabGroup({
    required this.group,
    required this.offset,
    required this.size,
  });

  final _TabGroup group;
  Offset offset;
  Size size;
}

class _NativeDetachedSessionArgs {
  const _NativeDetachedSessionArgs({
    required this.profileName,
    required this.splitAxis,
    required this.sessions,
  });

  final String profileName;
  final Axis splitAxis;
  final List<_NativeDetachedSessionInfo> sessions;

  String toJson() => jsonEncode({
    'type': 'detached-session',
    'profileName': profileName,
    'splitAxis': splitAxis == Axis.horizontal ? 'horizontal' : 'vertical',
    'sessions': [for (final session in sessions) session.toJson()],
  });

  factory _NativeDetachedSessionArgs.fromJson(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return _NativeDetachedSessionArgs(
      profileName: map['profileName'] as String? ?? 'Tindra',
      splitAxis: map['splitAxis'] == 'vertical'
          ? Axis.vertical
          : Axis.horizontal,
      sessions: [
        for (final item in (map['sessions'] as List<dynamic>? ?? const []))
          _NativeDetachedSessionInfo.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class _NativeDetachedSessionInfo {
  const _NativeDetachedSessionInfo({
    required this.sessionId,
    required this.profileId,
    required this.profileName,
    required this.cols,
    required this.rows,
  });

  final BigInt sessionId;
  final String profileId;
  final String profileName;
  final int cols;
  final int rows;

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId.toString(),
    'profileId': profileId,
    'profileName': profileName,
    'cols': cols,
    'rows': rows,
  };

  factory _NativeDetachedSessionInfo.fromJson(Map<String, dynamic> map) {
    return _NativeDetachedSessionInfo(
      sessionId: BigInt.parse(map['sessionId'] as String),
      profileId: map['profileId'] as String? ?? '',
      profileName: map['profileName'] as String? ?? 'Session',
      cols: map['cols'] as int? ?? 80,
      rows: map['rows'] as int? ?? 24,
    );
  }
}

enum _View { sessions, profiles, files, forwards, keys, settings }

@visibleForTesting
bool shouldShowPrivateKeyFieldForAuthMethod(String authMethod) =>
    authMethod == 'key';

@visibleForTesting
bool shouldDiscardPendingConnectionTab({
  required bool userCanceled,
  required bool hasSessionId,
}) => userCanceled && !hasSessionId;

@visibleForTesting
class HostKeyDecisionDetails extends StatelessWidget {
  const HostKeyDecisionDetails({
    super.key,
    required this.host,
    required this.port,
    required this.status,
    required this.actual,
    this.expected = '',
  });

  final String host;
  final int port;
  final String status;
  final String actual;
  final String expected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = status == 'changed'
        ? l10n.hostKeyChangedContent(actual, expected, host, port)
        : l10n.trustHostKeyContent(actual, host, port);
    return SelectableText(text);
  }
}

class _DetachedNativeWindowApp extends StatelessWidget {
  const _DetachedNativeWindowApp({required this.arguments});

  final String arguments;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: _DetachedNativeShell(arguments: arguments),
    );
  }
}

class _DetachedNativeShell extends StatefulWidget {
  const _DetachedNativeShell({required this.arguments});

  final String arguments;

  @override
  State<_DetachedNativeShell> createState() => _DetachedNativeShellState();
}

class _DetachedNativeShellState extends State<_DetachedNativeShell> {
  final FocusNode _focus = FocusNode(debugLabel: 'detached-terminal');
  late _NativeDetachedSessionArgs _args;
  final List<_SessionTab> _sessions = [];
  int _activeIdx = 0;
  bool _reattaching = false;

  _SessionTab? get _active => _sessions.isEmpty
      ? null
      : _sessions[_activeIdx.clamp(0, _sessions.length - 1)];

  void _applyTerminalSnapshot(_SessionTab tab, rust.TerminalSnapshot snapshot) {
    tab.snapshot = snapshot;
    tab.lastActivityAt = DateTime.now();
    if (snapshot.bell) {
      if (_active != tab) tab.hasBellActivity = true;
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  @override
  void initState() {
    super.initState();
    _args = _NativeDetachedSessionArgs.fromJson(widget.arguments);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await windowManager.setTitle('${_args.profileName} - Tindra');
      _focus.requestFocus();
    });
    for (final info in _args.sessions) {
      final tab =
          _SessionTab(profileId: info.profileId, profileName: info.profileName)
            ..sessionId = info.sessionId
            ..cols = info.cols
            ..rows = info.rows
            ..state = _ConnState.connected;
      tab.outputSub = rust
          .shellOutputStream(sessionId: info.sessionId)
          .listen(
            (snapshot) {
              _applyTerminalSnapshot(tab, snapshot);
              if (mounted) setState(() {});
            },
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
      _sessions.add(tab);
    }
  }

  @override
  void dispose() {
    for (final tab in _sessions) {
      if (_reattaching) tab.sessionId = null;
      tab.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  Future<void> _writeBytes(List<int> data) async {
    final id = _active?.sessionId;
    if (id == null) return;
    await rust.shellWrite(sessionId: id, data: data);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final bytes = <int>[];
    if (key == LogicalKeyboardKey.enter) {
      bytes.add(13);
    } else if (key == LogicalKeyboardKey.backspace) {
      bytes.add(127);
    } else if (key == LogicalKeyboardKey.tab) {
      bytes.add(9);
    } else if (key == LogicalKeyboardKey.escape) {
      bytes.add(27);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      bytes.addAll(const [27, 91, 65]);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      bytes.addAll(const [27, 91, 66]);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      bytes.addAll(const [27, 91, 67]);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      bytes.addAll(const [27, 91, 68]);
    } else if (event.character != null && event.character!.isNotEmpty) {
      bytes.addAll(utf8.encode(event.character!));
    }
    if (bytes.isEmpty) return KeyEventResult.ignored;
    _writeBytes(bytes);
    return KeyEventResult.handled;
  }

  Future<void> _setScrollback(_SessionTab tab, int rows) async {
    final id = tab.sessionId;
    if (id == null) return;
    final snapshot = await rust.shellSetScrollback(
      sessionId: id,
      rows: rows.clamp(0, terminalPrefs.value.scrollbackLimit),
    );
    if (!mounted) return;
    setState(() => tab.snapshot = snapshot);
  }

  Future<void> _attachToMainWindow() async {
    _reattaching = true;
    final args = _NativeDetachedSessionArgs(
      profileName: _args.profileName,
      splitAxis: _args.splitAxis,
      sessions: [
        for (final tab in _sessions)
          if (tab.sessionId != null)
            _NativeDetachedSessionInfo(
              sessionId: tab.sessionId!,
              profileId: tab.profileId,
              profileName: tab.displayName,
              cols: tab.cols,
              rows: tab.rows,
            ),
      ],
    );
    const channel = WindowMethodChannel(
      'tindra/session-windows',
      mode: ChannelMode.unidirectional,
    );
    await channel.invokeMethod('reattach-session', args.toJson());
    for (final tab in _sessions) {
      tab.sessionId = null;
    }
    await windowManager.close();
  }

  void _scheduleResize(_SessionTab tab, int cols, int rows) {
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

  Widget _termBody(_SessionTab tab, bool focused) {
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
        final fitCols = ((constraints.maxWidth - padding * 2) / charWidth)
            .floor()
            .clamp(20, 400);
        final fitRows = ((constraints.maxHeight - padding * 2) / lineHeight)
            .floor()
            .clamp(8, 200);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scheduleResize(tab, fitCols, fitRows);
        });

        return Padding(
          padding: const EdgeInsets.all(padding),
          child: _CellGrid(
            tab: tab,
            isFocused: focused && _focus.hasFocus,
            charWidth: charWidth,
            lineHeight: lineHeight,
            onReconnect: () async {},
            onMouseReport: _writeBytes,
            onScrollback: _setScrollback,
            onCopy: () async {
              final text = tab.selectedTerminalText ?? tab.snapshot?.text;
              if (text != null && text.isNotEmpty) {
                await Clipboard.setData(ClipboardData(text: text));
              }
            },
            onPaste: () async {
              final data = await Clipboard.getData('text/plain');
              final text = data?.text;
              if (text != null && text.isNotEmpty) {
                await _writeBytes(utf8.encode(text));
              }
            },
            onOpenUrl: _openDetachedUrl,
          ),
        );
      },
    );
  }

  Future<void> _openDetachedUrl(String url) async {
    if (Platform.isWindows) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else {
      await Process.run('xdg-open', [url]);
    }
  }

  Widget _content() {
    if (_sessions.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(l10n.noSession, style: _mono(size: 13, color: _ink2)),
      );
    }
    if (_sessions.length == 1) {
      return _termBody(_sessions.first, true);
    }
    final children = <Widget>[];
    for (var i = 0; i < _sessions.length; i++) {
      children.add(
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _activeIdx = i),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: i == _activeIdx ? _acc : _line),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _termBody(_sessions[i], i == _activeIdx),
            ),
          ),
        ),
      );
    }
    return _args.splitAxis == Axis.horizontal
        ? Row(children: children)
        : Column(children: children);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tBg,
      body: Column(
        children: [
          Container(
            height: 34,
            color: _bg1,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.open_in_new, size: 15, color: _ink3),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _args.profileName,
                    overflow: TextOverflow.ellipsis,
                    style: _mono(size: 12, color: _ink1),
                  ),
                ),
                _IconBtn(
                  icon: Icons.call_merge_outlined,
                  tooltip: 'Attach to main tabs',
                  onTap: _attachToMainWindow,
                ),
                _IconBtn(
                  icon: Icons.close,
                  tooltip: 'Close',
                  onTap: () => windowManager.close(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Focus(
              focusNode: _focus,
              autofocus: true,
              onKeyEvent: _onKey,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _focus.requestFocus,
                child: _content(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shell screen
// ============================================================================

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  static const _sessionWindowChannel = WindowMethodChannel(
    'tindra/session-windows',
    mode: ChannelMode.unidirectional,
  );

  final _passphrase = TextEditingController();
  final _termFocus = FocusNode(debugLabel: 'terminal');

  // Profile state
  List<rust.Profile> _profiles = [];
  String? _selectedProfileId;
  bool _profilesLoading = true;

  // Tab state
  final List<_TabGroup> _tabs = [];
  final List<_DetachedTabGroup> _detachedTabs = [];
  int _activeIdx = -1;

  // View routing
  _View _view = _View.sessions;
  bool _paletteOpen = false;
  bool _sidebarCollapsed = false;
  String _profileFilter = 'all';
  List<String> _quickConnectHistory = [];
  List<String> _quickConnectFavorites = [];
  List<String> _lastProfileIds = [];
  List<_SavedLayoutGroup> _lastLayoutGroups = [];

  // ignore: unused_field
  String? _sidebarError;

  rust.Profile? get _selectedProfile =>
      _profiles.where((p) => p.id == _selectedProfileId).firstOrNull;

  rust.Profile? _profileById(String id) =>
      _profiles.where((p) => p.id == id).firstOrNull;

  _TabGroup? get _activeGroup =>
      (_activeIdx >= 0 && _activeIdx < _tabs.length) ? _tabs[_activeIdx] : null;

  _SessionTab? get _activeTab => _activeGroup?.active;

  void _applyTerminalSnapshot(_SessionTab tab, rust.TerminalSnapshot snapshot) {
    tab.snapshot = snapshot;
    tab.lastActivityAt = DateTime.now();
    if (_activeTab != tab) tab.hasUnreadActivity = true;
    if (snapshot.bell) {
      if (_activeTab != tab) tab.hasBellActivity = true;
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  @override
  void initState() {
    super.initState();
    _sessionWindowChannel.setMethodCallHandler((call) async {
      if (call.method == 'reattach-session') {
        final raw = call.arguments as String?;
        if (raw != null) _reattachNativeSession(raw);
        return true;
      }
      throw MissingPluginException('Unknown method ${call.method}');
    });
    _loadDesktopState();
    _refreshProfiles();
  }

  File get _desktopStateFile {
    final base =
        Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.current.path;
    return File('$base\\Tindra\\desktop_state.json');
  }

  Future<void> _loadDesktopState() async {
    try {
      final file = _desktopStateFile;
      if (!await file.exists()) return;
      final state = _DesktopState.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
      if (!mounted) return;
      terminalPrefs.value = state.terminalPrefs;
      shortcutPrefs.value = state.shortcutPrefs;
      setState(() {
        _quickConnectHistory = state.quickConnectHistory.take(10).toList();
        _quickConnectFavorites = state.quickConnectFavorites.take(20).toList();
        _lastProfileIds = state.lastProfileIds.take(10).toList();
        _lastLayoutGroups = state.lastLayoutGroups.take(10).toList();
        _sidebarCollapsed = state.sidebarCollapsed;
      });
    } catch (_) {}
  }

  Future<void> _saveDesktopState() async {
    try {
      final file = _desktopStateFile;
      await file.parent.create(recursive: true);
      final lastProfileIds = [
        for (final group in _tabs)
          if (group.sessions.first.profileId != _localShellProfileId)
            group.sessions.first.profileId,
      ];
      final layoutGroups = [
        for (final group in _tabs)
          if (_SavedLayoutGroup.fromGroup(group) != null)
            _SavedLayoutGroup.fromGroup(group)!,
      ];
      _lastProfileIds = lastProfileIds;
      _lastLayoutGroups = layoutGroups;
      final state = _DesktopState(
        quickConnectHistory: _quickConnectHistory.take(10).toList(),
        quickConnectFavorites: _quickConnectFavorites.take(20).toList(),
        lastProfileIds: lastProfileIds,
        lastLayoutGroups: layoutGroups,
        sidebarCollapsed: _sidebarCollapsed,
        terminalPrefs: terminalPrefs.value,
        shortcutPrefs: shortcutPrefs.value,
      );
      await file.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {}
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
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
    await _openProfileAsTab(p, splitInto: splitInto, axis: axis);
  }

  Future<rust.Profile?> _pickProfileForConnection(String title) async {
    final filter = TextEditingController();
    try {
      return await showDialog<rust.Profile>(
        context: context,
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext);
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final q = filter.text.trim().toLowerCase();
              final matches = _profiles.where((p) {
                if (q.isEmpty) return true;
                return p.name.toLowerCase().contains(q) ||
                    p.host.toLowerCase().contains(q) ||
                    p.username.toLowerCase().contains(q) ||
                    p.notes.toLowerCase().contains(q);
              }).toList();
              return AlertDialog(
                title: Text(title),
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 28,
                ),
                contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 480,
                    maxWidth: 560,
                    maxHeight: 520,
                  ),
                  child: SizedBox(
                    width: 520,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: filter,
                                autofocus: true,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 18,
                                  ),
                                  labelText: l10n.search,
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _TinyButton(
                              icon: Icons.add,
                              label: l10n.newProfile,
                              onTap: () async {
                                final saved = await _createProfileFromPicker();
                                if (saved == null || !dialogContext.mounted) {
                                  return;
                                }
                                Navigator.pop(dialogContext, saved);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 360,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: _line),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: matches.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        l10n.noProfilesYet,
                                        style: _sans(size: 13, color: _ink2),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: matches.length,
                                    separatorBuilder: (_, _) =>
                                        Divider(height: 1, color: _line),
                                    itemBuilder: (_, i) {
                                      final p = matches[i];
                                      return ListTile(
                                        dense: true,
                                        minLeadingWidth: 18,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                        leading: _BarMark(
                                          accent: _accentForProfile(p),
                                        ),
                                        title: Text(
                                          p.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: _sans(
                                            size: 13.5,
                                            color: _ink0,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${p.username}@${p.host}:${p.port}',
                                          overflow: TextOverflow.ellipsis,
                                          style: _mono(
                                            size: 11.5,
                                            color: _ink3,
                                          ),
                                        ),
                                        trailing: Text(
                                          p.authMethod,
                                          style: _mono(
                                            size: 10.5,
                                            color: _ink3,
                                          ),
                                        ),
                                        onTap: () =>
                                            Navigator.pop(dialogContext, p),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () async {
                      final saved = await _createProfileFromPicker();
                      if (saved == null || !dialogContext.mounted) return;
                      Navigator.pop(dialogContext, saved);
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(l10n.newProfile),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(l10n.cancel),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      filter.dispose();
    }
  }

  Future<rust.Profile?> _createProfileFromPicker() async {
    final result = await showDialog<rust.Profile>(
      context: context,
      builder: (_) => const _ProfileDialog(),
    );
    if (result == null) return null;
    try {
      final saved = await rust.upsertProfile(profile: result);
      await _refreshProfiles();
      if (mounted) setState(() => _selectedProfileId = saved.id);
      return saved;
    } catch (e) {
      if (mounted) setState(() => _sidebarError = e.toString());
      return null;
    }
  }

  Future<void> _openProfilePickerAsTab() async {
    final l10n = AppLocalizations.of(context);
    final profile = await _pickProfileForConnection(l10n.pickProfileForNewTab);
    if (profile == null) return;
    setState(() => _selectedProfileId = profile.id);
    await _openProfileAsTab(profile);
  }

  Future<void> _openProfilePickerAsSplit(Axis axis) async {
    final group = _activeGroup;
    if (group == null) return;
    final l10n = AppLocalizations.of(context);
    final profile = await _pickProfileForConnection(l10n.pickProfileForSplit);
    if (profile == null) return;
    setState(() => _selectedProfileId = profile.id);
    await _openProfileAsTab(profile, splitInto: group, axis: axis);
  }

  Future<void> _openProfileAsTab(
    rust.Profile p, {
    _TabGroup? splitInto,
    Axis? axis,
  }) async {
    final tab = _SessionTab(profileId: p.id, profileName: p.name);
    final group = splitInto;
    final previousActiveIdx = _activeIdx;
    setState(() {
      if (group != null) {
        if (axis != null) group.splitAxis = axis;
        group.sessions.add(tab);
        group.splitWeights.add(1.0);
        group.normalizeWeights();
        group.activeIdx = group.sessions.length - 1;
      } else {
        _tabs.add(_TabGroup(profileName: p.name, first: tab));
        _activeIdx = _tabs.length - 1;
      }
      _view = _View.sessions;
    });
    unawaited(_saveDesktopState());

    try {
      if (p.transport != 'telnet') {
        final ok = await _ensureTrustedProfileHostKey(p);
        if (!ok) {
          await _discardPendingConnectionTab(
            tab,
            fallbackActiveIdx: previousActiveIdx,
          );
          return;
        }
      }
      final jump = rust.JumpHost(
        host: p.jumpHost,
        port: p.jumpPort == 0 ? 22 : p.jumpPort,
        username: p.jumpUsername,
        privateKeyPath: p.jumpPrivateKeyPath,
        passphrase: null,
      );
      final BigInt id;
      if (p.transport == 'telnet') {
        id = await rust.openShellTelnet(
          host: p.host,
          port: p.port,
          cols: tab.cols,
          rows: tab.rows,
        );
      } else if (p.authMethod == 'agent') {
        id = await rust.openShellAgent(
          host: p.host,
          port: p.port,
          username: p.username,
          cols: tab.cols,
          rows: tab.rows,
          jump: jump,
        );
      } else if (p.authMethod == 'password') {
        final password = await _promptPassword(p);
        if (password == null) {
          await _discardPendingConnectionTab(
            tab,
            fallbackActiveIdx: previousActiveIdx,
          );
          return;
        }
        id = await rust.openShellPassword(
          host: p.host,
          port: p.port,
          username: p.username,
          password: password,
          cols: tab.cols,
          rows: tab.rows,
          jump: jump,
        );
      } else if (p.authMethod == 'keyboard-interactive') {
        id = await _openKeyboardInteractiveShell(p, tab, jump);
      } else {
        id = await rust.openShellPubkey(
          host: p.host,
          port: p.port,
          username: p.username,
          privateKeyPath: p.privateKeyPath,
          passphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
          cols: tab.cols,
          rows: tab.rows,
          jump: jump,
        );
      }
      tab.sessionId = id;
      tab.outputSub = rust
          .shellOutputStream(sessionId: id)
          .listen(
            (snap) {
              _applyTerminalSnapshot(tab, snap);
              if (mounted) setState(() {});
            },
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

  Future<void> _discardPendingConnectionTab(
    _SessionTab tab, {
    required int fallbackActiveIdx,
  }) async {
    if (!shouldDiscardPendingConnectionTab(
      userCanceled: true,
      hasSessionId: tab.sessionId != null,
    )) {
      return;
    }
    await tab.dispose();
    if (!mounted) return;
    setState(() {
      for (var groupIndex = 0; groupIndex < _tabs.length; groupIndex++) {
        final group = _tabs[groupIndex];
        final sessionIndex = group.sessions.indexOf(tab);
        if (sessionIndex < 0) continue;
        if (group.sessions.length <= 1) {
          _tabs.removeAt(groupIndex);
          if (_tabs.isEmpty) {
            _activeIdx = -1;
          } else if (fallbackActiveIdx >= 0 &&
              fallbackActiveIdx < _tabs.length) {
            _activeIdx = fallbackActiveIdx;
          } else if (groupIndex >= _tabs.length) {
            _activeIdx = _tabs.length - 1;
          } else {
            _activeIdx = groupIndex;
          }
        } else {
          group.sessions.removeAt(sessionIndex);
          if (sessionIndex < group.splitWeights.length) {
            group.splitWeights.removeAt(sessionIndex);
          }
          group.normalizeWeights();
          if (group.activeIdx >= group.sessions.length) {
            group.activeIdx = group.sessions.length - 1;
          }
          _activeIdx = _tabs.indexOf(group);
        }
        break;
      }
      _view = _View.sessions;
    });
    unawaited(_saveDesktopState());
  }

  Future<void> _openQuickConnectDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    try {
      final raw = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final current = controller.text.trim();
            final isFavorite =
                current.isNotEmpty && _quickConnectFavorites.contains(current);
            return AlertDialog(
              title: Text(l10n.quickConnect),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'user@host:port',
                              hintText: 'xiu@example.com:22',
                            ),
                            onChanged: (_) => setDialogState(() {}),
                            onSubmitted: (_) =>
                                Navigator.pop(dialogContext, controller.text),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _IconBtn(
                          icon: isFavorite
                              ? Icons.star
                              : Icons.star_border_outlined,
                          tooltip: l10n.favorite,
                          onTap: current.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    if (isFavorite) {
                                      _quickConnectFavorites =
                                          _quickConnectFavorites
                                              .where((item) => item != current)
                                              .toList();
                                    } else {
                                      _quickConnectFavorites = [
                                        current,
                                        ..._quickConnectFavorites.where(
                                          (item) => item != current,
                                        ),
                                      ].take(20).toList();
                                    }
                                  });
                                  setDialogState(() {});
                                  unawaited(_saveDesktopState());
                                },
                        ),
                      ],
                    ),
                    if (_quickConnectFavorites.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        l10n.favorites,
                        style: _mono(
                          size: 11,
                          color: _ink2,
                          letterSpacing: 1.2,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in _quickConnectFavorites)
                            ActionChip(
                              avatar: Icon(Icons.star, size: 14, color: _acc),
                              label: Text(
                                item,
                                style: _mono(size: 11.5, color: _ink0),
                              ),
                              onPressed: () =>
                                  Navigator.pop(dialogContext, item),
                            ),
                        ],
                      ),
                    ],
                    if (_quickConnectHistory.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        l10n.recent,
                        style: _mono(
                          size: 11,
                          color: _ink2,
                          letterSpacing: 1.2,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in _quickConnectHistory)
                            ActionChip(
                              label: Text(
                                item,
                                style: _mono(size: 11.5, color: _ink0),
                              ),
                              onPressed: () =>
                                  Navigator.pop(dialogContext, item),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, controller.text),
                  child: Text(l10n.connect),
                ),
              ],
            );
          },
        ),
      );
      final profile = _profileFromQuickConnect(raw);
      if (profile == null) return;
      final value = raw!.trim();
      setState(() {
        _quickConnectHistory = [
          value,
          ..._quickConnectHistory.where((item) => item != value),
        ].take(10).toList();
      });
      unawaited(_saveDesktopState());
      await _openProfileAsTab(profile);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _restoreLastLayout() async {
    if (_lastLayoutGroups.isNotEmpty) {
      for (final saved in _lastLayoutGroups) {
        if (!mounted || saved.profileIds.isEmpty) return;
        final first = _profileById(saved.profileIds.first);
        if (first == null) continue;
        final before = _tabs.length;
        await _openProfileAsTab(first);
        if (!mounted || _tabs.length <= before) continue;
        final group = _tabs.last
          ..splitAxis = saved.splitAxis
          ..pinned = saved.pinned
          ..tabColor = saved.tabColor;
        if (saved.displayName.isNotEmpty) {
          group.active.displayName = saved.displayName;
        }
        for (final id in saved.profileIds.skip(1)) {
          final profile = _profileById(id);
          if (profile != null) {
            await _openProfileAsTab(
              profile,
              splitInto: group,
              axis: saved.splitAxis,
            );
          }
        }
        group.normalizeWeights();
        for (
          var i = 0;
          i < group.splitWeights.length && i < saved.splitWeights.length;
          i++
        ) {
          group.splitWeights[i] = saved.splitWeights[i].clamp(0.1, 20.0);
        }
        group.activeIdx = saved.activeIdx.clamp(0, group.sessions.length - 1);
        group.maximizedIdx = saved.maximizedIdx?.clamp(
          0,
          group.sessions.length - 1,
        );
        if (mounted) setState(() {});
      }
      return;
    }
    final ids = LinkedHashSet<String>.from(_lastProfileIds);
    if (ids.isEmpty) {
      ids.addAll(
        _tabs
            .map((group) => group.sessions.first.profileId)
            .where((id) => id != _localShellProfileId),
      );
    }
    for (final id in ids) {
      if (!mounted) return;
      final profile = _profileById(id);
      if (profile != null) {
        await _openProfileAsTab(profile);
      }
    }
  }

  rust.Profile? _profileFromQuickConnect(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    var rest = value;
    var username =
        Platform.environment['USERNAME'] ??
        Platform.environment['USER'] ??
        'user';
    final at = rest.indexOf('@');
    if (at >= 0) {
      username = rest.substring(0, at).trim();
      rest = rest.substring(at + 1).trim();
    }
    var host = rest;
    var port = 22;
    final colon = rest.lastIndexOf(':');
    if (colon > 0 && colon < rest.length - 1) {
      final parsed = int.tryParse(rest.substring(colon + 1));
      if (parsed != null) {
        port = parsed;
        host = rest.substring(0, colon);
      }
    }
    if (host.trim().isEmpty || username.trim().isEmpty) return null;
    return rust.Profile(
      id: 'quick:${DateTime.now().microsecondsSinceEpoch}',
      name: '$username@$host',
      host: host.trim(),
      port: port,
      username: username.trim(),
      privateKeyPath: '',
      notes: 'quick-connect',
      authMethod: 'agent',
      jumpHost: '',
      jumpPort: 22,
      jumpUsername: '',
      jumpPrivateKeyPath: '',
      transport: 'ssh',
    );
  }

  Future<void> _openLocalShell() async {
    final tab = _SessionTab(
      profileId: _localShellProfileId,
      profileName: 'Local Shell',
    );
    setState(() {
      _tabs.add(_TabGroup(profileName: 'Local Shell', first: tab));
      _activeIdx = _tabs.length - 1;
      _view = _View.sessions;
    });
    unawaited(_saveDesktopState());
    await _connectLocalIntoExistingSession(tab);
  }

  Future<void> _connectLocalIntoExistingSession(_SessionTab tab) async {
    try {
      final settings = appSettings.value;
      final id = await rust.openLocalShellWithOptions(
        shell: settings.localShell.trim().isEmpty
            ? null
            : settings.localShell.trim(),
        cwd: settings.localShellCwd.trim().isEmpty
            ? null
            : settings.localShellCwd.trim(),
        env: _parseLocalShellEnv(settings.localShellEnv),
        cols: tab.cols,
        rows: tab.rows,
      );
      tab.sessionId = id;
      tab.outputSub = rust
          .shellOutputStream(sessionId: id)
          .listen(
            (snap) {
              _applyTerminalSnapshot(tab, snap);
              if (mounted) setState(() {});
            },
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

  List<rust.LocalShellEnvVar> _parseLocalShellEnv(String raw) {
    return raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty && !line.startsWith('#') && line.contains('='),
        )
        .map((line) {
          final idx = line.indexOf('=');
          return rust.LocalShellEnvVar(
            name: line.substring(0, idx).trim(),
            value: line.substring(idx + 1),
          );
        })
        .where((entry) => entry.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _connectIntoExistingSession(
    rust.Profile p,
    _SessionTab tab,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (p.transport != 'telnet') {
        final ok = await _ensureTrustedProfileHostKey(p);
        if (!ok) {
          tab.error = l10n.hostKeyNotTrusted;
          tab.state = _ConnState.disconnected;
          if (mounted) setState(() {});
          return;
        }
      }
      final jump = rust.JumpHost(
        host: p.jumpHost,
        port: p.jumpPort == 0 ? 22 : p.jumpPort,
        username: p.jumpUsername,
        privateKeyPath: p.jumpPrivateKeyPath,
        passphrase: null,
      );
      final BigInt id;
      if (p.transport == 'telnet') {
        id = await rust.openShellTelnet(
          host: p.host,
          port: p.port,
          cols: tab.cols,
          rows: tab.rows,
        );
      } else if (p.authMethod == 'agent') {
        id = await rust.openShellAgent(
          host: p.host,
          port: p.port,
          username: p.username,
          cols: tab.cols,
          rows: tab.rows,
          jump: jump,
        );
      } else if (p.authMethod == 'password') {
        final password = await _promptPassword(p);
        if (password == null) {
          tab.error = l10n.passwordRequired;
          tab.state = _ConnState.disconnected;
          if (mounted) setState(() {});
          return;
        }
        id = await rust.openShellPassword(
          host: p.host,
          port: p.port,
          username: p.username,
          password: password,
          cols: tab.cols,
          rows: tab.rows,
          jump: jump,
        );
      } else if (p.authMethod == 'keyboard-interactive') {
        id = await _openKeyboardInteractiveShell(p, tab, jump);
      } else {
        id = await rust.openShellPubkey(
          host: p.host,
          port: p.port,
          username: p.username,
          privateKeyPath: p.privateKeyPath,
          passphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
          cols: tab.cols,
          rows: tab.rows,
          jump: jump,
        );
      }
      tab.sessionId = id;
      tab.outputSub = rust
          .shellOutputStream(sessionId: id)
          .listen(
            (snap) {
              _applyTerminalSnapshot(tab, snap);
              if (mounted) setState(() {});
            },
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
    if (_activeGroup == null) return;
    await _openProfilePickerAsSplit(Axis.horizontal);
  }

  Future<void> _splitVertical() async {
    if (_activeGroup == null) return;
    await _openProfilePickerAsSplit(Axis.vertical);
  }

  void _moveTabGroup(int from, int to) {
    if (from < 0 || from >= _tabs.length || to < 0 || to >= _tabs.length) {
      return;
    }
    if (from == to) return;
    setState(() {
      final activeGroup = _activeGroup;
      final moved = _tabs.removeAt(from);
      _tabs.insert(to, moved);
      if (activeGroup != null) {
        _activeIdx = _tabs.indexOf(activeGroup);
      }
    });
    unawaited(_saveDesktopState());
  }

  Future<void> _duplicateTabGroup(int idx) async {
    if (idx < 0 || idx >= _tabs.length) return;
    final tab = _tabs[idx].active;
    if (tab.profileId == _localShellProfileId) {
      await _openLocalShell();
      return;
    }
    final profile = _profileById(tab.profileId);
    if (profile != null) {
      await _openProfileAsTab(profile);
    }
  }

  Future<void> _closeOtherTabGroups(int idx) async {
    if (idx < 0 || idx >= _tabs.length) return;
    for (var i = _tabs.length - 1; i >= 0; i--) {
      if (i != idx) {
        await _closeTab(i);
      }
    }
    if (mounted) {
      setState(() => _activeIdx = _tabs.isEmpty ? -1 : 0);
      unawaited(_saveDesktopState());
    }
  }

  Future<void> _closeTabGroupsToRight(int idx) async {
    if (idx < 0 || idx >= _tabs.length - 1) return;
    for (var i = _tabs.length - 1; i > idx; i--) {
      await _closeTab(i);
    }
    unawaited(_saveDesktopState());
  }

  void _moveActiveTabGroupBy(int delta) {
    if (_activeIdx < 0 || _tabs.length < 2) return;
    final target = (_activeIdx + delta).clamp(0, _tabs.length - 1);
    if (target == _activeIdx) return;
    _moveTabGroup(_activeIdx, target);
  }

  Future<void> _detachActiveTabGroup() async {
    await _detachTabGroup(_activeIdx);
  }

  void _toggleActiveTabPin() {
    _togglePinTabGroup(_activeIdx);
  }

  void _dropTabGroupIntoSplit(int from, Axis axis) {
    final target = _activeGroup;
    if (target == null || from < 0 || from >= _tabs.length) return;
    final source = _tabs[from];
    if (identical(source, target)) {
      setState(() => target.splitAxis = axis);
      unawaited(_saveDesktopState());
      return;
    }
    setState(() {
      target.splitAxis = axis;
      target.sessions.addAll(source.sessions);
      target.splitWeights.addAll(source.sessions.map((_) => 1.0));
      target.normalizeWeights();
      target.activeIdx = target.sessions.length - source.sessions.length;
      _tabs.removeAt(from);
      _activeIdx = _tabs.indexOf(target);
    });
    unawaited(_saveDesktopState());
    _termFocus.requestFocus();
  }

  Future<void> _detachTabGroup(int idx) async {
    if (idx < 0 || idx >= _tabs.length) return;
    final group = _tabs[idx];
    final l10n = AppLocalizations.of(context);
    final args = _NativeDetachedSessionArgs(
      profileName: group.profileName,
      splitAxis: group.splitAxis,
      sessions: [
        for (final session in group.sessions)
          if (session.sessionId != null)
            _NativeDetachedSessionInfo(
              sessionId: session.sessionId!,
              profileId: session.profileId,
              profileName: session.displayName,
              cols: session.cols,
              rows: session.rows,
        ),
      ],
    );
    if (args.sessions.isEmpty) {
      _showShellMessage(l10n.noDetachableSession);
      return;
    }
    final controller = await WindowController.create(
      WindowConfiguration(arguments: args.toJson(), hiddenAtLaunch: true),
    );
    await controller.show();
    for (final session in group.sessions) {
      final sub = session.outputSub;
      session.outputSub = null;
      await sub?.cancel();
    }
    if (!mounted) return;
    setState(() {
      _tabs.removeAt(idx);
      if (_tabs.isEmpty) {
        _activeIdx = -1;
      } else if (_activeIdx >= _tabs.length) {
        _activeIdx = _tabs.length - 1;
      } else if (_activeIdx > idx) {
        _activeIdx -= 1;
      }
      _view = _View.sessions;
    });
    unawaited(_saveDesktopState());
  }

  void _reattachDetachedTabGroup(int idx) {
    if (idx < 0 || idx >= _detachedTabs.length) return;
    setState(() {
      final detached = _detachedTabs.removeAt(idx);
      _tabs.add(detached.group);
      _activeIdx = _tabs.length - 1;
      _view = _View.sessions;
    });
    unawaited(_saveDesktopState());
    _termFocus.requestFocus();
  }

  Future<void> _closeDetachedTabGroup(int idx) async {
    if (idx < 0 || idx >= _detachedTabs.length) return;
    final detached = _detachedTabs.removeAt(idx);
    if (mounted) setState(() {});
    await detached.group.dispose();
    unawaited(_saveDesktopState());
  }

  void _moveDetachedTabGroup(int idx, Offset delta) {
    if (idx < 0 || idx >= _detachedTabs.length) return;
    setState(() {
      final item = _detachedTabs[idx];
      item.offset += delta;
      final screen = MediaQuery.sizeOf(context);
      item.offset = Offset(
        item.offset.dx.clamp(0, (screen.width - 180).clamp(0, screen.width)),
        item.offset.dy.clamp(
          36,
          (screen.height - 120).clamp(36, screen.height),
        ),
      );
    });
  }

  void _reattachNativeSession(String raw) {
    final l10n = AppLocalizations.of(context);
    final args = _NativeDetachedSessionArgs.fromJson(raw);
    final sessions = <_SessionTab>[];
    for (final info in args.sessions) {
      final tab =
          _SessionTab(profileId: info.profileId, profileName: info.profileName)
            ..sessionId = info.sessionId
            ..cols = info.cols
            ..rows = info.rows
            ..state = _ConnState.connected;
      tab.outputSub = rust
          .shellOutputStream(sessionId: info.sessionId)
          .listen(
            (snapshot) {
              _applyTerminalSnapshot(tab, snapshot);
              if (mounted) setState(() {});
            },
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
      sessions.add(tab);
    }
    if (sessions.isEmpty) {
      _showShellMessage(l10n.noDetachableSession);
      return;
    }
    setState(() {
      final group = _TabGroup(
        profileName: args.profileName,
        first: sessions.first,
      )..splitAxis = args.splitAxis;
      for (final session in sessions.skip(1)) {
        group.sessions.add(session);
        group.splitWeights.add(1.0);
      }
      group.normalizeWeights();
      _tabs.add(group);
      _activeIdx = _tabs.length - 1;
      _view = _View.sessions;
    });
    unawaited(_saveDesktopState());
    _termFocus.requestFocus();
  }

  void _showShellMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
      group.splitWeights.removeAt(idx);
      group.normalizeWeights();
      if (group.activeIdx >= group.sessions.length) {
        group.activeIdx = group.sessions.length - 1;
      }
    });
    await session.dispose();
    unawaited(_saveDesktopState());
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
      final fresh = _SessionTab(
        profileId: _localShellProfileId,
        profileName: 'Local Shell',
      );
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

  Future<void> _setTerminalScrollback(_SessionTab tab, int rows) async {
    final id = tab.sessionId;
    if (id == null) return;
    final snapshot = await rust.shellSetScrollback(
      sessionId: id,
      rows: rows.clamp(0, terminalPrefs.value.scrollbackLimit),
    );
    if (!mounted) return;
    setState(() => tab.snapshot = snapshot);
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
    unawaited(_saveDesktopState());
  }

  void _switchTab(int idx) {
    if (idx == _activeIdx) return;
    setState(() {
      _activeIdx = idx;
      _activeGroup?.active.hasUnreadActivity = false;
      _activeGroup?.active.hasBellActivity = false;
    });
    _termFocus.requestFocus();
  }

  void _resizeSplit(_TabGroup group, int dividerIndex, double deltaPixels) {
    if (dividerIndex < 0 || dividerIndex + 1 >= group.sessions.length) return;
    setState(() {
      group.normalizeWeights();
      final delta = deltaPixels / 180.0;
      final left = (group.splitWeights[dividerIndex] + delta).clamp(0.35, 8.0);
      final right = (group.splitWeights[dividerIndex + 1] - delta).clamp(
        0.35,
        8.0,
      );
      group.splitWeights[dividerIndex] = left;
      group.splitWeights[dividerIndex + 1] = right;
    });
    unawaited(_saveDesktopState());
  }

  void _activateSplitPane(_TabGroup group, int paneIndex) {
    if (paneIndex < 0 || paneIndex >= group.sessions.length) return;
    setState(() {
      group.activeIdx = paneIndex;
      group.sessions[paneIndex].hasUnreadActivity = false;
      group.sessions[paneIndex].hasBellActivity = false;
    });
    _termFocus.requestFocus();
    unawaited(_saveDesktopState());
  }

  void _focusAdjacentSplitPane(int direction) {
    final group = _activeGroup;
    if (group == null || group.sessions.length < 2) return;
    final next =
        (group.activeIdx + direction + group.sessions.length) %
        group.sessions.length;
    _activateSplitPane(group, next);
  }

  void _toggleMaximizeSplitPane() {
    final group = _activeGroup;
    if (group == null || group.sessions.length < 2) return;
    setState(() {
      group.maximizedIdx = group.maximizedIdx == null ? group.activeIdx : null;
    });
    unawaited(_saveDesktopState());
  }

  Future<void> _renameTabGroup(int idx) async {
    if (idx < 0 || idx >= _tabs.length) return;
    final l10n = AppLocalizations.of(context);
    final group = _tabs[idx];
    final controller = TextEditingController(text: group.displayName);
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.renameTab),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.tabName),
            onSubmitted: (_) => Navigator.pop(context, controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(l10n.renameTab),
            ),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty) return;
      setState(() {
        group.profileName = name.trim();
        group.active.displayName = name.trim();
      });
      unawaited(_saveDesktopState());
    } finally {
      controller.dispose();
    }
  }

  void _togglePinTabGroup(int idx) {
    if (idx < 0 || idx >= _tabs.length) return;
    setState(() {
      final group = _tabs[idx];
      group.pinned = !group.pinned;
      group.active.pinned = group.pinned;
      _tabs.sort((a, b) {
        if (a.pinned == b.pinned) return 0;
        return a.pinned ? -1 : 1;
      });
      _activeIdx = _tabs.indexOf(group);
    });
    unawaited(_saveDesktopState());
  }

  void _setTabGroupColor(int idx, Color? color) {
    if (idx < 0 || idx >= _tabs.length) return;
    setState(() {
      final group = _tabs[idx];
      group.tabColor = color;
      group.active.tabColor = color;
    });
    unawaited(_saveDesktopState());
  }

  Future<void> _openTerminalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return;
    }
    if (Platform.isWindows) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else {
      await Process.run('xdg-open', [url]);
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
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final check = viaJump == null
        ? await rust.probeHostKey(host: host, port: port)
        : await rust.probeHostKeyViaJump(host: host, port: port, jump: viaJump);
    if (!mounted) return false;
    if (check.status == 'trusted') return true;
    if (check.status == 'changed') {
      final replace = await showDialog<bool>(
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
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.close),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.replaceHostKey),
            ),
          ],
        ),
      );
      if (replace == true) {
        await rust.deleteHostKey(host: host, port: port);
        await rust.trustHostKey(
          host: host,
          port: port,
          fingerprint: check.actual,
        );
        return true;
      }
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

  Future<BigInt> _openKeyboardInteractiveShell(
    rust.Profile profile,
    _SessionTab tab,
    rust.JumpHost jump,
  ) async {
    final responses = <String>[];
    final passwordRequired = AppLocalizations.of(context).passwordRequired;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        return await rust.openShellKeyboardInteractive(
          host: profile.host,
          port: profile.port,
          username: profile.username,
          responses: responses,
          cols: tab.cols,
          rows: tab.rows,
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
    final tab = _activeTab;
    final text = chooseTerminalCopyText(
      selectionText: tab?.selectedTerminalText,
      screenText: tab?.snapshot?.text,
    );
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final decision = assessTerminalPaste(text);
    if (terminalPrefs.value.warnOnLargePaste &&
        decision.shouldConfirm &&
        mounted) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.confirmPasteTitle),
          content: Text(
            l10n.confirmPasteContent(decision.lineCount, decision.byteCount),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.paste),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final activeSnapshot = _activeTab?.snapshot;
    final payload = activeSnapshot?.bracketedPasteMode == true
        ? '\x1b[200~${decision.text}\x1b[201~'
        : decision.normalizedForPty;
    await _writeBytes(utf8.encode(payload));
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
      if (_shortcutReservesTerminalInput(logical, shift)) {
        return null;
      }
      final ctrlLetters = <LogicalKeyboardKey, int>{
        LogicalKeyboardKey.keyA: 0x01,
        LogicalKeyboardKey.keyB: 0x02,
        LogicalKeyboardKey.keyC: 0x03,
        LogicalKeyboardKey.keyD: 0x04,
        LogicalKeyboardKey.keyE: 0x05,
        LogicalKeyboardKey.keyF: 0x06,
        LogicalKeyboardKey.keyG: 0x07,
        LogicalKeyboardKey.keyH: 0x08,
        LogicalKeyboardKey.keyI: 0x09,
        LogicalKeyboardKey.keyJ: 0x0A,
        LogicalKeyboardKey.keyK: 0x0B,
        LogicalKeyboardKey.keyL: 0x0C,
        LogicalKeyboardKey.keyM: 0x0D,
        LogicalKeyboardKey.keyN: 0x0E,
        LogicalKeyboardKey.keyO: 0x0F,
        LogicalKeyboardKey.keyP: 0x10,
        LogicalKeyboardKey.keyQ: 0x11,
        LogicalKeyboardKey.keyR: 0x12,
        LogicalKeyboardKey.keyS: 0x13,
        LogicalKeyboardKey.keyT: 0x14,
        LogicalKeyboardKey.keyU: 0x15,
        LogicalKeyboardKey.keyV: 0x16,
        LogicalKeyboardKey.keyW: 0x17,
        LogicalKeyboardKey.keyX: 0x18,
        LogicalKeyboardKey.keyY: 0x19,
        LogicalKeyboardKey.keyZ: 0x1A,
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

  bool _shortcutReservesTerminalInput(LogicalKeyboardKey key, bool shift) {
    final control = HardwareKeyboard.instance.isControlPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    for (final spec in shortcutPrefs.value.bindings.values) {
      final activator = _parseShortcutActivator(spec);
      if (activator == null) continue;
      if (activator.trigger == key &&
          activator.control == control &&
          activator.shift == shift &&
          activator.alt == alt &&
          activator.meta == meta) {
        return true;
      }
    }
    return false;
  }

  KeyEventResult _onTermKey(FocusNode node, KeyEvent event) {
    final tab = _activeTab;
    if (tab == null || tab.state != _ConnState.connected) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (_shortcutReservesTerminalInput(
        event.logicalKey,
        HardwareKeyboard.instance.isShiftPressed,
      )) {
        return KeyEventResult.ignored;
      }
    }
    final bytes = _keyEventToBytes(event);
    if (bytes != null) {
      _writeBytes(bytes);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scheduleResize(_SessionTab tab, int cols, int rows) {
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
      await _saveDesktopState();
    } catch (e) {
      if (mounted) setState(() => _sidebarError = e.toString());
    }
  }

  void _togglePalette() => setState(() => _paletteOpen = !_paletteOpen);
  void _closePalette() => setState(() => _paletteOpen = false);

  @override
  void dispose() {
    _sessionWindowChannel.setMethodCallHandler(null);
    for (final t in _tabs) {
      t.dispose();
    }
    for (final t in _detachedTabs) {
      t.group.dispose();
    }
    _passphrase.dispose();
    _termFocus.dispose();
    super.dispose();
  }

  // ---------------------- Build ----------------------

  Map<ShortcutActivator, Intent> _shortcutMap() {
    final bindings = shortcutPrefs.value.bindings;
    final entries = <ShortcutActivator, Intent>{};
    void add(String action, Intent intent) {
      final activator = _parseShortcutActivator(
        bindings[action] ?? _defaultShortcutBindings[action] ?? 'None',
      );
      if (activator != null) entries.putIfAbsent(activator, () => intent);
    }

    add('newTab', const _NewTabIntent());
    add('closeTab', const _CloseTabIntent());
    add('nextTab', const _NextTabIntent());
    add('prevTab', const _PrevTabIntent());
    add('settings', const _SettingsIntent());
    add('palette', const _PaletteIntent());
    add('splitRight', const _SplitHorizontalIntent());
    add('splitDown', const _SplitVerticalIntent());
    add('copy', const _CopyScreenIntent());
    add('paste', const _PasteClipboardIntent());
    add('reconnect', const _ReconnectIntent());
    add('duplicateTab', const _DuplicateTabIntent());
    add('closeOtherTabs', const _CloseOtherTabsIntent());
    add('closeTabsToRight', const _CloseTabsToRightIntent());
    add('prevPane', const _PrevPaneIntent());
    add('nextPane', const _NextPaneIntent());
    add('maximizePane', const _MaximizePaneIntent());
    add('moveTabLeft', const _MoveTabLeftIntent());
    add('moveTabRight', const _MoveTabRightIntent());
    add('detachTab', const _DetachTabIntent());
    add('pinTab', const _PinTabIntent());
    add('closePane', const _ClosePaneIntent());
    return entries;
  }

  SingleActivator? _parseShortcutActivator(String spec) {
    if (spec == 'None') return null;
    final parts = spec.split('+').map((p) => p.trim()).toList();
    if (parts.isEmpty) return null;
    final keyName = parts.last.toUpperCase();
    final key = switch (keyName) {
      'T' => LogicalKeyboardKey.keyT,
      'W' => LogicalKeyboardKey.keyW,
      'K' => LogicalKeyboardKey.keyK,
      'H' => LogicalKeyboardKey.keyH,
      'E' => LogicalKeyboardKey.keyE,
      'C' => LogicalKeyboardKey.keyC,
      'V' => LogicalKeyboardKey.keyV,
      'R' => LogicalKeyboardKey.keyR,
      'D' => LogicalKeyboardKey.keyD,
      'M' => LogicalKeyboardKey.keyM,
      'O' => LogicalKeyboardKey.keyO,
      'L' => LogicalKeyboardKey.keyL,
      'N' => LogicalKeyboardKey.keyN,
      'B' => LogicalKeyboardKey.keyB,
      'P' => LogicalKeyboardKey.keyP,
      'TAB' => LogicalKeyboardKey.tab,
      'PAGEDOWN' => LogicalKeyboardKey.pageDown,
      'PAGEUP' => LogicalKeyboardKey.pageUp,
      'LEFT' => LogicalKeyboardKey.arrowLeft,
      'RIGHT' => LogicalKeyboardKey.arrowRight,
      'UP' => LogicalKeyboardKey.arrowUp,
      'DOWN' => LogicalKeyboardKey.arrowDown,
      'HOME' => LogicalKeyboardKey.home,
      'END' => LogicalKeyboardKey.end,
      'INSERT' => LogicalKeyboardKey.insert,
      'DELETE' => LogicalKeyboardKey.delete,
      'BACKSPACE' => LogicalKeyboardKey.backspace,
      ',' => LogicalKeyboardKey.comma,
      'F1' => LogicalKeyboardKey.f1,
      'F2' => LogicalKeyboardKey.f2,
      'F3' => LogicalKeyboardKey.f3,
      'F4' => LogicalKeyboardKey.f4,
      'F5' => LogicalKeyboardKey.f5,
      'F6' => LogicalKeyboardKey.f6,
      'F7' => LogicalKeyboardKey.f7,
      'F8' => LogicalKeyboardKey.f8,
      'F9' => LogicalKeyboardKey.f9,
      'F10' => LogicalKeyboardKey.f10,
      'F11' => LogicalKeyboardKey.f11,
      'F12' => LogicalKeyboardKey.f12,
      _ => null,
    };
    if (key == null) return null;
    final mods = parts.take(parts.length - 1).map((p) => p.toLowerCase());
    return SingleActivator(
      key,
      control: mods.contains('ctrl'),
      shift: mods.contains('shift'),
      alt: mods.contains('alt'),
      meta: mods.contains('meta'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _shortcutMap(),
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewTabIntent: CallbackAction<_NewTabIntent>(
            onInvoke: (_) {
              if (_selectedProfile != null) _connectSelected();
              return null;
            },
          ),
          _CloseTabIntent: CallbackAction<_CloseTabIntent>(
            onInvoke: (_) {
              _closeActiveSession();
              return null;
            },
          ),
          _NextTabIntent: CallbackAction<_NextTabIntent>(
            onInvoke: (_) {
              if (_tabs.length >= 2) {
                _switchTab((_activeIdx + 1) % _tabs.length);
              }
              return null;
            },
          ),
          _PrevTabIntent: CallbackAction<_PrevTabIntent>(
            onInvoke: (_) {
              if (_tabs.length >= 2) {
                _switchTab((_activeIdx - 1 + _tabs.length) % _tabs.length);
              }
              return null;
            },
          ),
          _SettingsIntent: CallbackAction<_SettingsIntent>(
            onInvoke: (_) {
              _openSettingsView();
              return null;
            },
          ),
          _PaletteIntent: CallbackAction<_PaletteIntent>(
            onInvoke: (_) {
              _togglePalette();
              return null;
            },
          ),
          _SplitHorizontalIntent: CallbackAction<_SplitHorizontalIntent>(
            onInvoke: (_) {
              _splitHorizontal();
              return null;
            },
          ),
          _SplitVerticalIntent: CallbackAction<_SplitVerticalIntent>(
            onInvoke: (_) {
              _splitVertical();
              return null;
            },
          ),
          _CopyScreenIntent: CallbackAction<_CopyScreenIntent>(
            onInvoke: (_) {
              _copyScreen();
              return null;
            },
          ),
          _PasteClipboardIntent: CallbackAction<_PasteClipboardIntent>(
            onInvoke: (_) {
              _pasteClipboard();
              return null;
            },
          ),
          _ReconnectIntent: CallbackAction<_ReconnectIntent>(
            onInvoke: (_) {
              _reconnectActive();
              return null;
            },
          ),
          _DuplicateTabIntent: CallbackAction<_DuplicateTabIntent>(
            onInvoke: (_) {
              _duplicateTabGroup(_activeIdx);
              return null;
            },
          ),
          _CloseOtherTabsIntent: CallbackAction<_CloseOtherTabsIntent>(
            onInvoke: (_) {
              _closeOtherTabGroups(_activeIdx);
              return null;
            },
          ),
          _CloseTabsToRightIntent: CallbackAction<_CloseTabsToRightIntent>(
            onInvoke: (_) {
              _closeTabGroupsToRight(_activeIdx);
              return null;
            },
          ),
          _PrevPaneIntent: CallbackAction<_PrevPaneIntent>(
            onInvoke: (_) {
              _focusAdjacentSplitPane(-1);
              return null;
            },
          ),
          _NextPaneIntent: CallbackAction<_NextPaneIntent>(
            onInvoke: (_) {
              _focusAdjacentSplitPane(1);
              return null;
            },
          ),
          _MaximizePaneIntent: CallbackAction<_MaximizePaneIntent>(
            onInvoke: (_) {
              _toggleMaximizeSplitPane();
              return null;
            },
          ),
          _MoveTabLeftIntent: CallbackAction<_MoveTabLeftIntent>(
            onInvoke: (_) {
              _moveActiveTabGroupBy(-1);
              return null;
            },
          ),
          _MoveTabRightIntent: CallbackAction<_MoveTabRightIntent>(
            onInvoke: (_) {
              _moveActiveTabGroupBy(1);
              return null;
            },
          ),
          _DetachTabIntent: CallbackAction<_DetachTabIntent>(
            onInvoke: (_) {
              _detachActiveTabGroup();
              return null;
            },
          ),
          _PinTabIntent: CallbackAction<_PinTabIntent>(
            onInvoke: (_) {
              _toggleActiveTabPin();
              return null;
            },
          ),
          _ClosePaneIntent: CallbackAction<_ClosePaneIntent>(
            onInvoke: (_) {
              _closeActiveSession();
              return null;
            },
          ),
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
                      title: _titleText(context),
                      onPalette: _togglePalette,
                      sidebarCollapsed: _sidebarCollapsed,
                      onToggleSidebar: () {
                        setState(() => _sidebarCollapsed = !_sidebarCollapsed);
                        _saveDesktopState();
                      },
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: _Sidebar(
                              key: ValueKey(_sidebarCollapsed),
                              view: _view,
                              sessionsCount: _tabs.length,
                              collapsed: _sidebarCollapsed,
                              onToggleCollapsed: () {
                                setState(
                                  () => _sidebarCollapsed = !_sidebarCollapsed,
                                );
                                _saveDesktopState();
                              },
                              onView: (v) => setState(() => _view = v),
                              onPalette: _togglePalette,
                            ),
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
                    tabs: _tabs,
                    activeTabIndex: _activeIdx,
                    onClose: _closePalette,
                    onOpenProfile: (p) {
                      _closePalette();
                      setState(() => _selectedProfileId = p.id);
                      _connectSelected();
                    },
                    onSwitchTab: (idx) {
                      _closePalette();
                      _switchTab(idx);
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
                    onQuickConnect: () {
                      _closePalette();
                      _openQuickConnectDialog();
                    },
                    onRestoreLayout: () {
                      _closePalette();
                      _restoreLastLayout();
                    },
                    onToggleSidebar: () {
                      _closePalette();
                      setState(() => _sidebarCollapsed = !_sidebarCollapsed);
                      _saveDesktopState();
                    },
                    onRenameTab: () {
                      _closePalette();
                      _renameTabGroup(_activeIdx);
                    },
                    onDuplicateTab: () {
                      _closePalette();
                      _duplicateTabGroup(_activeIdx);
                    },
                    onCloseOtherTabs: () {
                      _closePalette();
                      _closeOtherTabGroups(_activeIdx);
                    },
                    onCloseTabsToRight: () {
                      _closePalette();
                      _closeTabGroupsToRight(_activeIdx);
                    },
                    onPrevPane: () {
                      _closePalette();
                      _focusAdjacentSplitPane(-1);
                    },
                    onNextPane: () {
                      _closePalette();
                      _focusAdjacentSplitPane(1);
                    },
                    onToggleMaximizePane: () {
                      _closePalette();
                      _toggleMaximizeSplitPane();
                    },
                    onMoveTabLeft: () {
                      _closePalette();
                      _moveActiveTabGroupBy(-1);
                    },
                    onMoveTabRight: () {
                      _closePalette();
                      _moveActiveTabGroupBy(1);
                    },
                    onDetachTab: () {
                      _closePalette();
                      _detachActiveTabGroup();
                    },
                    onPinTab: () {
                      _closePalette();
                      _toggleActiveTabPin();
                    },
                    onClosePane: () {
                      _closePalette();
                      _closeActiveSession();
                    },
                  ),
                for (var i = 0; i < _detachedTabs.length; i++)
                  _DetachedSessionWindow(
                    key: ValueKey(_detachedTabs[i].group),
                    item: _detachedTabs[i],
                    index: i,
                    termFocus: _termFocus,
                    onTermKey: _onTermKey,
                    onMove: _moveDetachedTabGroup,
                    onReattach: _reattachDetachedTabGroup,
                    onClose: _closeDetachedTabGroup,
                    onAddTab: _openProfilePickerAsTab,
                    onSplitH: _splitHorizontal,
                    onSplitV: _splitVertical,
                    onCopy: _copyScreen,
                    onPaste: _pasteClipboard,
                    onWriteBytes: _writeBytes,
                    onScrollback: _setTerminalScrollback,
                    onReconnect: _reconnectActive,
                    onDisconnect: _disconnectActive,
                    scheduleResize: _scheduleResize,
                    selectedProfile: _selectedProfile,
                    profileById: _profileById,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _titleText(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = _activeTab;
    if (_view == _View.sessions && t != null) {
      return l10n.appTitleWithProfile(t.profileName);
    }
    return l10n.appTitle;
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
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ViewHead(
              eyebrow: l10n.home,
              title: _greeting(),
              lede: l10n.liveSessionsSummary(_profiles.length, _tabs.length),
              actions: [
                _GhostButton(
                  icon: Icons.terminal_outlined,
                  label: l10n.localShell,
                  onTap: _openLocalShell,
                ),
                _PrimaryButton(
                  icon: Icons.add,
                  label: l10n.newProfile,
                  onTap: () => _openProfileDialog(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _BlockHead(title: l10n.profiles, tools: _filterChips()),
            _profilesGrid(),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final l10n = AppLocalizations.of(context);
    final h = DateTime.now().hour;
    if (h < 5) return l10n.goodEvening;
    if (h < 12) return l10n.goodMorning;
    if (h < 18) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  List<Widget> _filterChips() {
    final l10n = AppLocalizations.of(context);
    final tags = <String>{'all'};
    for (final p in _profiles) {
      for (final t
          in (p.notes.isEmpty
              ? <String>[]
              : p.notes.split(',').map((e) => e.trim()))) {
        if (t.isNotEmpty) tags.add(t);
      }
    }
    return [
      for (final t in tags.take(6))
        _Chip(
          label: t == 'all' ? l10n.all : t,
          on: _profileFilter == t,
          onTap: () => setState(() => _profileFilter = t),
        ),
    ];
  }

  Widget _profilesGrid() {
    final l10n = AppLocalizations.of(context);
    if (_profilesLoading) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: _acc),
          ),
        ),
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
            Text(l10n.noProfilesYet, style: _display(size: 22)),
            const SizedBox(height: 6),
            Text(l10n.pickProfilePrompt, style: _sans(color: _ink2)),
            const SizedBox(height: 14),
            _PrimaryButton(
              icon: Icons.add,
              label: l10n.newProfile,
              onTap: () => _openProfileDialog(),
            ),
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
    onMoveTab: _moveTabGroup,
    onDuplicateTab: _duplicateTabGroup,
    onCloseOtherTabs: _closeOtherTabGroups,
    onCloseTabsToRight: _closeTabGroupsToRight,
    onRenameTab: _renameTabGroup,
    onTogglePinTab: _togglePinTabGroup,
    onSetTabColor: _setTabGroupColor,
    onSplitDrop: _dropTabGroupIntoSplit,
    onDetachDrop: _detachTabGroup,
    onDetachActive: _detachActiveTabGroup,
    onResizeSplit: _resizeSplit,
    onActivateSplit: _activateSplitPane,
    onFocusPrevSplit: () => _focusAdjacentSplitPane(-1),
    onFocusNextSplit: () => _focusAdjacentSplitPane(1),
    onToggleMaximizeSplit: _toggleMaximizeSplitPane,
    onAddTab: _openProfilePickerAsTab,
    onSplitH: _splitHorizontal,
    onSplitV: _splitVertical,
    onCopy: _copyScreen,
    onPaste: _pasteClipboard,
    onOpenUrl: _openTerminalUrl,
    onWriteBytes: _writeBytes,
    onScrollback: _setTerminalScrollback,
    onReconnect: _reconnectActive,
    onDisconnect: _disconnectActive,
    scheduleResize: _scheduleResize,
    selectedProfile: _selectedProfile,
    profileById: _profileById,
  );

  Widget _profilesView() {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ViewHead(
            eyebrow: l10n.profiles,
            title: l10n.profileCount(_profiles.length),
            lede: l10n.profilesLede,
            actions: [
              _PrimaryButton(
                icon: Icons.add,
                label: l10n.newProfile,
                onTap: () => _openProfileDialog(),
              ),
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
          if (_selectedProfile != null)
            _selectedProfileFooter(_selectedProfile!),
        ],
      ),
    );
  }

  /// Hidden affordance the integration tests rely on: a button labelled
  /// `Open profileName` mirroring the tab-bar trailing plus button.
  Widget _selectedProfileFooter(rust.Profile p) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Tooltip(
            message: l10n.openProfile(p.name),
            child: FilledButton.icon(
              onPressed: _connectSelected,
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: Text(
                l10n.openProfile(p.name),
                style: _sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: _isLight ? Colors.white : _Pal.dBg0,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _ink0,
                foregroundColor: _isLight ? Colors.white : _Pal.dBg0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filesView() => _FilesView(profiles: _profiles);
  Widget _forwardsView() =>
      _ForwardsView(profiles: _profiles, selectedProfile: _selectedProfile);
  Widget _keysView() => const _KeysView();
  Widget _settingsView() => _SettingsView(onSave: _saveSettings);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ============================================================================
// Generic view chrome ??view header, block header, chips, buttons.
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
                Text(
                  title,
                  style: _display(
                    size: 36,
                    weight: FontWeight.w500,
                    color: _ink0,
                  ),
                ),
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
  const _BlockHead({required this.title, this.tools});
  final String title;
  final dynamic tools; // String? or List<Widget>?

  @override
  Widget build(BuildContext context) {
    Widget? right;
    if (tools is String) right = Text(tools as String, style: _blockSub());
    if (tools is List<Widget>) {
      right = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < (tools as List).length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            (tools as List)[i] as Widget,
          ],
        ],
      );
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
            style: _mono(size: 11, color: on ? _acc : (_hover ? _ink1 : _ink2)),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
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
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
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
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
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
  const _TinyButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
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
              Text(
                widget.label,
                style: _sans(size: 11.5, color: _ink1, weight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostLink extends StatefulWidget {
  const _GhostLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
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
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ViewHead(
            eyebrow: l10n.networkPortForwardsEyebrow,
            title: l10n.forwards,
            lede: l10n.forwardsLede,
            actions: [
              _GhostButton(
                icon: Icons.refresh,
                label: l10n.refresh,
                onTap: _refresh,
              ),
              _PrimaryButton(
                icon: Icons.add,
                label: l10n.newForward,
                onTap: widget.selectedProfile == null
                    ? null
                    : () => _openNewDialog(widget.selectedProfile!),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: _acc,
                  ),
                ),
              ),
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
                  Text(
                    l10n.noActiveTunnels,
                    style: _display(
                      size: 22,
                      color: _ink0,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.selectedProfile == null
                        ? l10n.pickProfileThenForward
                        : l10n.openLocalForwardToProfile(
                            widget.selectedProfile!.name,
                          ),
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
    final l10n = AppLocalizations.of(context);
    final isSocks = forward.kind == 'socks';
    final isRemote = forward.kind == 'remote';
    final type = isSocks ? 'D' : (isRemote ? 'R' : 'L');
    final typeColor = isSocks
        ? _Pal.cSky
        : (isRemote ? _Pal.cAmber : _Pal.cEmerald);
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
                width: 28,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color.lerp(typeColor, _bg2, 0.84),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type,
                  style: _mono(
                    size: 11,
                    color: typeColor,
                    weight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${forward.localAddr}:${forward.localPort}',
                  style: _display(
                    size: 16,
                    weight: FontWeight.w500,
                    color: _ink0,
                    letterSpacing: -0.05,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _Pal.cEmerald,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _Pal.cEmerald.withValues(alpha: 0.2),
                          blurRadius: 0,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    l10n.openStatus.toUpperCase(),
                    style: _mono(
                      size: 10.5,
                      color: _Pal.cEmerald,
                      letterSpacing: 1.2,
                      weight: FontWeight.w500,
                    ),
                  ),
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
                  child: _endpoint(
                    isRemote ? 'REMOTE' : l10n.local.toUpperCase(),
                    '${forward.localAddr}:${forward.localPort}',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text('->', style: _mono(size: 16, color: _acc)),
                      Text(
                        l10n.via.toLowerCase(),
                        style: _mono(
                          size: 10,
                          color: _ink3,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _endpoint(
                    isSocks ? 'SOCKS5' : l10n.remote.toUpperCase(),
                    isSocks
                        ? 'dynamic target'
                        : isRemote
                        ? '${forward.remoteHost}:${forward.remotePort} local'
                        : '${forward.remoteHost}:${forward.remotePort}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _line),
          const SizedBox(height: 10),
          Row(
            children: [
              _GhostLink(
                icon: Icons.delete_outline,
                label: l10n.drop.toLowerCase(),
                onTap: onStop,
                danger: true,
              ),
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
        Text(
          value,
          style: _mono(size: 12, color: _ink0),
          overflow: TextOverflow.ellipsis,
        ),
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
  String _mode = 'local';
  bool _busy = false;
  String? _error;

  Future<void> _open() async {
    final p = widget.profile;
    setState(() {
      _busy = true;
      _error = null;
    });
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
        if (_mode == 'socks') {
          await rust.openSocksForwardAgent(
            host: p.host,
            port: p.port,
            username: p.username,
            jump: jump,
            localAddr: _localAddr.text.trim(),
            localPort: lp,
          );
        } else if (_mode == 'remote') {
          await rust.openRemoteForwardAgent(
            host: p.host,
            port: p.port,
            username: p.username,
            jump: jump,
            remoteAddr: _localAddr.text.trim(),
            remotePort: lp,
            localHost: _remoteHost.text.trim(),
            localPort: rp,
          );
        } else {
          await rust.openLocalForwardAgent(
            host: p.host,
            port: p.port,
            username: p.username,
            jump: jump,
            localAddr: _localAddr.text.trim(),
            localPort: lp,
            remoteHost: _remoteHost.text.trim(),
            remotePort: rp,
          );
        }
      } else if (p.authMethod == 'password') {
        final password = await _promptForwardPassword(p);
        if (password == null) return;
        if (_mode == 'socks') {
          await rust.openSocksForwardPassword(
            host: p.host,
            port: p.port,
            username: p.username,
            password: password,
            jump: jump,
            localAddr: _localAddr.text.trim(),
            localPort: lp,
          );
        } else if (_mode == 'remote') {
          await rust.openRemoteForwardPassword(
            host: p.host,
            port: p.port,
            username: p.username,
            password: password,
            jump: jump,
            remoteAddr: _localAddr.text.trim(),
            remotePort: lp,
            localHost: _remoteHost.text.trim(),
            localPort: rp,
          );
        } else {
          await rust.openLocalForwardPassword(
            host: p.host,
            port: p.port,
            username: p.username,
            password: password,
            jump: jump,
            localAddr: _localAddr.text.trim(),
            localPort: lp,
            remoteHost: _remoteHost.text.trim(),
            remotePort: rp,
          );
        }
      } else if (p.authMethod == 'keyboard-interactive') {
        await _openKeyboardInteractiveForward(p, jump, lp, rp);
      } else {
        if (_mode == 'socks') {
          await rust.openSocksForwardPubkey(
            host: p.host,
            port: p.port,
            username: p.username,
            privateKeyPath: p.privateKeyPath,
            passphrase: null,
            jump: jump,
            localAddr: _localAddr.text.trim(),
            localPort: lp,
          );
        } else if (_mode == 'remote') {
          await rust.openRemoteForwardPubkey(
            host: p.host,
            port: p.port,
            username: p.username,
            privateKeyPath: p.privateKeyPath,
            passphrase: null,
            jump: jump,
            remoteAddr: _localAddr.text.trim(),
            remotePort: lp,
            localHost: _remoteHost.text.trim(),
            localPort: rp,
          );
        } else {
          await rust.openLocalForwardPubkey(
            host: p.host,
            port: p.port,
            username: p.username,
            privateKeyPath: p.privateKeyPath,
            passphrase: null,
            jump: jump,
            localAddr: _localAddr.text.trim(),
            localPort: lp,
            remoteHost: _remoteHost.text.trim(),
            remotePort: rp,
          );
        }
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

  Future<String?> _promptForwardPassword(rust.Profile profile) async {
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

  Future<void> _openKeyboardInteractiveForward(
    rust.Profile profile,
    rust.JumpHost jump,
    int listenPort,
    int targetPort,
  ) async {
    final responses = <String>[];
    final passwordRequired = AppLocalizations.of(context).passwordRequired;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        if (_mode == 'socks') {
          await rust.openSocksForwardKeyboardInteractive(
            host: profile.host,
            port: profile.port,
            username: profile.username,
            responses: responses,
            jump: jump,
            localAddr: _localAddr.text.trim(),
            localPort: listenPort,
          );
        } else if (_mode == 'remote') {
          await rust.openRemoteForwardKeyboardInteractive(
            host: profile.host,
            port: profile.port,
            username: profile.username,
            responses: responses,
            jump: jump,
            remoteAddr: _localAddr.text.trim(),
            remotePort: listenPort,
            localHost: _remoteHost.text.trim(),
            localPort: targetPort,
          );
        } else {
          await rust.openLocalForwardKeyboardInteractive(
            host: profile.host,
            port: profile.port,
            username: profile.username,
            responses: responses,
            jump: jump,
            localAddr: _localAddr.text.trim(),
            localPort: listenPort,
            remoteHost: _remoteHost.text.trim(),
            remotePort: targetPort,
          );
        }
        return;
      } catch (e) {
        final prompt = _keyboardInteractivePromptFromError(e.toString());
        if (prompt == null) rethrow;
        final answer = await _promptForwardKeyboardInteractive(profile, prompt);
        if (answer == null) throw passwordRequired;
        responses.add(answer);
      }
    }
    throw 'Too many keyboard-interactive prompts.';
  }

  String? _keyboardInteractivePromptFromError(String error) {
    const marker = 'keyboard-interactive prompt has no configured response: ';
    final idx = error.indexOf(marker);
    if (idx < 0) return null;
    return error.substring(idx + marker.length).trim();
  }

  Future<String?> _promptForwardKeyboardInteractive(
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: _bg1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _line2),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(l10n.newForward.toUpperCase(), style: _eyebrow()),
                const Spacer(),
                _IconBtn(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _mode == 'socks'
                  ? 'SOCKS5 dynamic forward'
                  : (_mode == 'remote' ? 'Remote forward' : l10n.localForward),
              style: _display(size: 22, weight: FontWeight.w500, color: _ink0),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.localForwardDescription(widget.profile.name),
              style: _sans(size: 12.5, color: _ink2),
            ),
            const SizedBox(height: 14),
            _Seg<String>(
              value: _mode,
              options: const [
                ('local', 'LOCAL'),
                ('remote', 'REMOTE'),
                ('socks', 'SOCKS5'),
              ],
              onChanged: (v) => setState(() => _mode = v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _fwdField(
                    l10n.localAddr.toUpperCase(),
                    _localAddr,
                    _mode == 'remote' ? '0.0.0.0' : '127.0.0.1',
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: _fwdField(l10n.port.toUpperCase(), _localPort, '0'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Icon(Icons.arrow_downward, size: 14, color: _acc),
              ),
            ),
            if (_mode != 'socks')
              Row(
                children: [
                  Expanded(
                    child: _fwdField(
                      _mode == 'remote'
                          ? 'LOCAL TARGET'
                          : l10n.remoteHost.toUpperCase(),
                      _remoteHost,
                      _mode == 'remote' ? '127.0.0.1' : 'cache.svc',
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: _fwdField(
                      l10n.port.toUpperCase(),
                      _remotePort,
                      '6379',
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _bg2,
                  border: Border.all(color: _line2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'SOCKS5 clients choose the remote host and port dynamically.',
                  style: _sans(size: 12.5, color: _ink2),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: _mono(size: 11.5, color: _Pal.cRose)),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _GhostButton(
                  icon: Icons.close,
                  label: l10n.cancel.toUpperCase(),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                _PrimaryButton(
                  icon: Icons.bolt,
                  label: l10n.open.toUpperCase(),
                  onTap: _busy ? null : _open,
                ),
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
            child: Text(
              label,
              style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.3),
            ),
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
    final l10n = AppLocalizations.of(context);
    final n = ms.toInt();
    if (n <= 0) return l10n.unknown;
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
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
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ViewHead(
            eyebrow: l10n.trustHostKeysEyebrow,
            title: l10n.trustedHostKeys,
            lede: l10n.trustedHostKeysDescription,
            actions: [
              _GhostButton(
                icon: Icons.refresh,
                label: l10n.refresh,
                onTap: _reload,
              ),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<rust.HostKey>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: _acc,
                      ),
                    ),
                  ),
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
                      Text(
                        l10n.noTrustedKeysYet,
                        style: _display(
                          size: 22,
                          color: _ink0,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.connectOnceRememberHost,
                        style: _sans(size: 12.5, color: _ink2),
                      ),
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
                    for (var i = 0; i < keys.length; i++)
                      _keyRow(keys[i], i == keys.length - 1, _fmt),
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: last ? Colors.transparent : _line),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 18,
            decoration: BoxDecoration(
              color: _Pal.cEmerald,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              '${k.host}:${k.port}',
              style: _mono(size: 12.5, color: _ink0),
            ),
          ),
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Text(
                  'SSH-ED25519',
                  style: _mono(size: 10.5, color: _ink3, letterSpacing: 1.0),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    k.fingerprint,
                    style: _mono(size: 11.5, color: _ink1),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Text(
                  '${l10n.first.toLowerCase()} ${fmt(k.firstSeenUnixMs)}',
                  style: _mono(size: 10.5, color: _ink3),
                ),
                const SizedBox(width: 10),
                Text(
                  '${l10n.last.toLowerCase()} ${fmt(k.lastSeenUnixMs)}',
                  style: _mono(size: 10.5, color: _ink3),
                ),
              ],
            ),
          ),
          _IconBtn(
            icon: Icons.delete_outline,
            iconSize: 14,
            danger: true,
            onTap: () => _delete(k),
          ),
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
  late String _localShell;
  late String _localShellCwd;
  late String _localShellEnv;
  late _TerminalCursorStyle _cursorStyle;
  late bool _copyOnSelect;
  late int _scrollbackLimit;
  late bool _warnOnLargePaste;
  late Map<String, String> _shortcutBindings;

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
    _localShell = s.localShell;
    _localShellCwd = s.localShellCwd;
    _localShellEnv = s.localShellEnv;
    final terminal = terminalPrefs.value;
    _cursorStyle = terminal.cursorStyle;
    _copyOnSelect = terminal.copyOnSelect;
    _scrollbackLimit = terminal.scrollbackLimit;
    _warnOnLargePaste = terminal.warnOnLargePaste;
    _shortcutBindings = {...shortcutPrefs.value.bindings};
  }

  Future<void> _commit() async {
    appAccent.value = _accent;
    appDense.value = _dense;
    terminalPrefs.value = _TerminalPrefs(
      cursorStyle: _cursorStyle,
      copyOnSelect: _copyOnSelect,
      scrollbackLimit: _scrollbackLimit,
      warnOnLargePaste: _warnOnLargePaste,
    );
    shortcutPrefs.value = _ShortcutPrefs(bindings: {..._shortcutBindings});
    await widget.onSave(
      rust.Settings(
        theme: _theme,
        fontFamily: _font.trim().isEmpty ? 'JetBrains Mono' : _font.trim(),
        fontSize: _size,
        quakeHotkey: _quake.trim(),
        locale: _locale,
        localShell: _localShell.trim(),
        localShellCwd: _localShellCwd.trim(),
        localShellEnv: _localShellEnv.trim(),
      ),
    );
  }

  Future<void> _exportThemeToClipboard() async {
    final payload = jsonEncode({
      'theme': _theme,
      'accent': _accent,
      'dense': _dense,
      'fontFamily': _font,
      'fontSize': _size,
      'cursorStyle': _cursorStyle.name,
      'copyOnSelect': _copyOnSelect,
      'scrollbackLimit': _scrollbackLimit,
      'warnOnLargePaste': _warnOnLargePaste,
      'shortcuts': _shortcutBindings,
    });
    await Clipboard.setData(ClipboardData(text: payload));
  }

  Future<void> _importThemeFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    setState(() {
      _theme = decoded['theme'] as String? ?? _theme;
      _accent = decoded['accent'] as String? ?? _accent;
      _dense = decoded['dense'] as bool? ?? _dense;
      _font = decoded['fontFamily'] as String? ?? _font;
      _size = (decoded['fontSize'] as num?)?.toDouble() ?? _size;
      _cursorStyle = _TerminalCursorStyle.values.firstWhere(
        (style) => style.name == decoded['cursorStyle'],
        orElse: () => _cursorStyle,
      );
      _copyOnSelect = decoded['copyOnSelect'] as bool? ?? _copyOnSelect;
      _scrollbackLimit =
          (decoded['scrollbackLimit'] as int? ?? _scrollbackLimit).clamp(
            100,
            10000,
          );
      _warnOnLargePaste =
          decoded['warnOnLargePaste'] as bool? ?? _warnOnLargePaste;
      final decodedShortcuts = decoded['shortcuts'];
      if (decodedShortcuts is Map<String, dynamic>) {
        _shortcutBindings = {
          ..._shortcutBindings,
          for (final entry in decodedShortcuts.entries)
            if (entry.value is String) entry.key: entry.value as String,
        };
      }
    });
    appAccent.value = _accent;
    appDense.value = _dense;
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
            eyebrow: l10n.preferences,
            title: l10n.settings,
            lede: l10n.settingsLede,
            actions: [
              _PrimaryButton(
                icon: Icons.check,
                label: l10n.apply.toUpperCase(),
                onTap: _commit,
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 1100 ? 3 : 1;
              final groups = [
                _appearanceGroup(),
                _terminalGroup(),
                _keybindingGroup(),
                _localShellGroup(l10n),
                _syncGroup(l10n),
                _diagnosticsGroup(l10n),
              ];
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final g in groups)
                    SizedBox(
                      width: cols == 1
                          ? c.maxWidth
                          : (c.maxWidth - (cols - 1) * 16) / cols,
                      child: g,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _appearanceGroup() {
    final l10n = AppLocalizations.of(context);
    return _SGroup(
      title: l10n.appearance,
      children: [
        _SRow(
          label: l10n.theme,
          hint: l10n.appearanceThemeHint,
          child: _Seg<String>(
            value: _theme,
            options: [
              ('dark', l10n.dark.toUpperCase()),
              ('light', l10n.light.toUpperCase()),
            ],
            onChanged: (v) {
              setState(() => _theme = v);
              appSettings.value = rust.Settings(
                theme: v,
                fontFamily: _font,
                fontSize: _size,
                quakeHotkey: _quake,
                locale: _locale,
                localShell: _localShell,
                localShellCwd: _localShellCwd,
                localShellEnv: _localShellEnv,
              );
            },
          ),
        ),
        _SRow(
          label: l10n.accent,
          hint: l10n.accentHint,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in _accentChoices)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Swatch(
                    color: colorForAccent(a.$1),
                    label: _accentLabel(l10n, a.$1),
                    selected: _accent == a.$1,
                    onTap: () {
                      setState(() => _accent = a.$1);
                      appAccent.value = a.$1;
                    },
                  ),
                ),
            ],
          ),
        ),
        _SRow(
          label: l10n.density,
          hint: l10n.densityHint,
          child: _Seg<bool>(
            value: _dense,
            options: [
              (false, l10n.cozy.toUpperCase()),
              (true, l10n.compact.toUpperCase()),
            ],
            onChanged: (v) {
              setState(() => _dense = v);
              appDense.value = v;
            },
          ),
        ),
        _SRow(
          label: l10n.themePreset,
          hint: l10n.themePresetHint,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyButton(
                icon: Icons.upload_outlined,
                label: l10n.exportTheme,
                onTap: _exportThemeToClipboard,
              ),
              _TinyButton(
                icon: Icons.download_outlined,
                label: l10n.importTheme,
                onTap: _importThemeFromClipboard,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _accentLabel(AppLocalizations l10n, String value) {
    return switch (value) {
      'frost' => l10n.paletteFrost,
      'aurora' => l10n.paletteAurora,
      'glacier' => l10n.paletteGlacier,
      'twilight' => l10n.paletteTwilight,
      'coal' => l10n.paletteCoal,
      'snow' => l10n.paletteSnow,
      'rose' => l10n.paletteRose,
      'amber' => l10n.paletteAmber,
      _ => value,
    };
  }

  Widget _terminalGroup() {
    final l10n = AppLocalizations.of(context);
    return _SGroup(
      title: l10n.terminal,
      children: [
        _SRow(
          label: l10n.font,
          hint: l10n.fontHint,
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
          label: l10n.size(_size.toStringAsFixed(0)),
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
                value: _size,
                min: 9,
                max: 24,
                divisions: 15,
                onChanged: (v) => setState(() => _size = v),
              ),
            ),
          ),
        ),
        _SRow(
          label: 'Cursor',
          hint: 'Terminal cursor shape',
          child: _Seg<_TerminalCursorStyle>(
            value: _cursorStyle,
            options: const [
              (_TerminalCursorStyle.block, 'BLOCK'),
              (_TerminalCursorStyle.bar, 'BAR'),
              (_TerminalCursorStyle.underline, 'UNDER'),
            ],
            onChanged: (v) => setState(() => _cursorStyle = v),
          ),
        ),
        _SRow(
          label: 'Copy on select',
          hint: 'Copy selected terminal text immediately',
          child: _Seg<bool>(
            value: _copyOnSelect,
            options: const [(false, 'OFF'), (true, 'ON')],
            onChanged: (v) => setState(() => _copyOnSelect = v),
          ),
        ),
        _SRow(
          label: 'Paste warning',
          hint: 'Ask before multiline or large paste',
          child: _Seg<bool>(
            value: _warnOnLargePaste,
            options: const [(true, 'ON'), (false, 'OFF')],
            onChanged: (v) => setState(() => _warnOnLargePaste = v),
          ),
        ),
        _SRow(
          label: 'Scrollback ${_scrollbackLimit.toString()}',
          hint: 'Rows kept behind the current screen',
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
                value: _scrollbackLimit.toDouble(),
                min: 100,
                max: 10000,
                divisions: 99,
                onChanged: (v) => setState(() => _scrollbackLimit = v.round()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _localShellGroup(AppLocalizations l10n) {
    return _SGroup(
      title: l10n.localShell,
      children: [
        _SRow(
          label: l10n.localShellCommand,
          hint: l10n.localShellCommandHint,
          child: TextField(
            controller: TextEditingController(text: _localShell),
            onChanged: (v) => _localShell = v,
            decoration: const InputDecoration(
              hintText: 'powershell.exe',
              isDense: true,
            ),
            style: _mono(size: 12.5, color: _ink0),
          ),
        ),
        _SRow(
          label: l10n.localShellWorkingDirectory,
          hint: l10n.localShellWorkingDirectoryHint,
          child: TextField(
            controller: TextEditingController(text: _localShellCwd),
            onChanged: (v) => _localShellCwd = v,
            decoration: const InputDecoration(
              hintText: r'C:\Users\XIU',
              isDense: true,
            ),
            style: _mono(size: 12.5, color: _ink0),
          ),
        ),
        _SRow(
          label: l10n.localShellEnvironment,
          hint: l10n.localShellEnvironmentHint,
          child: TextField(
            controller: TextEditingController(text: _localShellEnv),
            onChanged: (v) => _localShellEnv = v,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'NAME=value',
              isDense: true,
            ),
            style: _mono(size: 12.5, color: _ink0),
          ),
        ),
      ],
    );
  }

  Widget _keybindingGroup() {
    final l10n = AppLocalizations.of(context);
    return _SGroup(
      title: l10n.keyboardShortcuts,
      children: [
        for (final action in _defaultShortcutBindings.keys)
          _SRow(
            label: _shortcutLabel(l10n, action),
            child: _ShortcutCapture(
              value:
                  _shortcutBindings[action] ??
                  _defaultShortcutBindings[action]!,
              onChanged: (v) => setState(() => _shortcutBindings[action] = v),
              onReset: () => setState(
                () => _shortcutBindings[action] =
                    _defaultShortcutBindings[action]!,
              ),
            ),
          ),
      ],
    );
  }

  String _shortcutLabel(AppLocalizations l10n, String action) {
    return switch (action) {
      'newTab' => l10n.newTab,
      'closeTab' => l10n.closeTab,
      'nextTab' => l10n.nextTab,
      'prevTab' => l10n.previousTab,
      'palette' => l10n.commandPalette,
      'settings' => l10n.settings,
      'splitRight' => l10n.splitRight,
      'splitDown' => l10n.splitDown,
      'copy' => l10n.copy,
      'paste' => l10n.paste,
      'reconnect' => l10n.reconnect,
      'duplicateTab' => l10n.duplicateTab,
      'closeOtherTabs' => l10n.closeOtherTabs,
      'closeTabsToRight' => l10n.closeTabsToRight,
      'prevPane' => l10n.previousPane,
      'nextPane' => l10n.nextPane,
      'maximizePane' => l10n.maximizePane,
      'moveTabLeft' => l10n.moveTabLeft,
      'moveTabRight' => l10n.moveTabRight,
      'detachTab' => l10n.detachTab,
      'pinTab' => l10n.pinTab,
      'closePane' => l10n.closePane,
      _ => _shortcutLabels[action] ?? action,
    };
  }

  Widget _syncGroup(AppLocalizations l10n) {
    return _SGroup(
      title: l10n.syncSystem,
      children: [
        _SRow(
          label: l10n.quakeHotkey,
          hint: l10n.quakeHotkeyDescription,
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
          label: l10n.language,
          hint: l10n.language,
          child: _Seg<String>(
            value: _locale,
            options: [
              ('system', l10n.systemLanguage.toUpperCase()),
              ('en', l10n.english.toUpperCase()),
              ('ko', l10n.korean.toUpperCase()),
            ],
            onChanged: (v) => setState(() => _locale = v),
          ),
        ),
      ],
    );
  }

  Widget _diagnosticsGroup(AppLocalizations l10n) {
    return _SGroup(
      title: l10n.diagnostics,
      children: [
        _DiagnosticRow(label: l10n.appVersion, value: '1.0.0+1'),
        _DiagnosticRow(label: l10n.rustCoreVersion, value: rust.coreVersion()),
        _DiagnosticRow(label: 'Secret backend', future: rust.secretBackend()),
        _DiagnosticRow(label: l10n.profilesPath, future: rust.profilesPath()),
        _DiagnosticRow(label: l10n.settingsPath, future: rust.settingsPath()),
        _DiagnosticRow(
          label: l10n.expectedLogDirectory,
          future: rust.expectedLogDir(),
        ),
      ],
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, this.value, this.future});

  final String label;
  final String? value;
  final Future<String>? future;

  @override
  Widget build(BuildContext context) {
    Widget valueWidget(String text) =>
        SelectableText(text, style: _mono(size: 11, color: _ink1));
    return _SRow(
      label: label,
      child: future == null
          ? valueWidget(value ?? '')
          : FutureBuilder<String>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return valueWidget(snapshot.error.toString());
                }
                return valueWidget(
                  snapshot.data ?? AppLocalizations.of(context).loading,
                );
              },
            ),
    );
  }
}

class _ShortcutCapture extends StatefulWidget {
  const _ShortcutCapture({
    required this.value,
    required this.onChanged,
    required this.onReset,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onReset;

  @override
  State<_ShortcutCapture> createState() => _ShortcutCaptureState();
}

class _ShortcutCaptureState extends State<_ShortcutCapture> {
  final _focus = FocusNode(debugLabel: 'shortcut-capture');
  bool _recording = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _recording ? 'Press keys' : widget.value;
    return KeyboardListener(
      focusNode: _focus,
      onKeyEvent: _recording ? _onKey : null,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _recording = true);
              _focus.requestFocus();
            },
            child: Container(
              constraints: const BoxConstraints(minWidth: 132),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _recording ? _accSoft : _bg2,
                border: Border.all(color: _recording ? _acc : _line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                text,
                style: _mono(
                  size: 11.5,
                  color: _recording ? _acc : _ink1,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
          _TinyButton(
            icon: Icons.backspace_outlined,
            label: 'Clear',
            onTap: () => widget.onChanged('None'),
          ),
          _TinyButton(
            icon: Icons.restore_outlined,
            label: 'Reset',
            onTap: widget.onReset,
          ),
        ],
      ),
    );
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _recording = false);
      return;
    }
    final label = _shortcutLabelForEvent(event);
    if (label == null) return;
    widget.onChanged(label);
    setState(() => _recording = false);
  }

  String? _shortcutLabelForEvent(KeyEvent event) {
    final keyName = _shortcutKeyName(event.logicalKey);
    if (keyName == null) return null;
    final parts = <String>[];
    if (HardwareKeyboard.instance.isControlPressed) parts.add('Ctrl');
    if (HardwareKeyboard.instance.isAltPressed) parts.add('Alt');
    if (HardwareKeyboard.instance.isShiftPressed) parts.add('Shift');
    if (HardwareKeyboard.instance.isMetaPressed) parts.add('Meta');
    final modifierOnly = {
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    }.contains(event.logicalKey);
    if (modifierOnly) return null;
    parts.add(keyName);
    return parts.join('+');
  }

  String? _shortcutKeyName(LogicalKeyboardKey key) {
    if (key.keyLabel.length == 1) return key.keyLabel.toUpperCase();
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.comma) return ',';
    if (key == LogicalKeyboardKey.arrowLeft) return 'Left';
    if (key == LogicalKeyboardKey.arrowRight) return 'Right';
    if (key == LogicalKeyboardKey.arrowUp) return 'Up';
    if (key == LogicalKeyboardKey.arrowDown) return 'Down';
    if (key == LogicalKeyboardKey.pageUp) return 'PageUp';
    if (key == LogicalKeyboardKey.pageDown) return 'PageDown';
    if (key == LogicalKeyboardKey.home) return 'Home';
    if (key == LogicalKeyboardKey.end) return 'End';
    if (key == LogicalKeyboardKey.insert) return 'Insert';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.backspace) return 'Backspace';
    return switch (key) {
      LogicalKeyboardKey.f1 => 'F1',
      LogicalKeyboardKey.f2 => 'F2',
      LogicalKeyboardKey.f3 => 'F3',
      LogicalKeyboardKey.f4 => 'F4',
      LogicalKeyboardKey.f5 => 'F5',
      LogicalKeyboardKey.f6 => 'F6',
      LogicalKeyboardKey.f7 => 'F7',
      LogicalKeyboardKey.f8 => 'F8',
      LogicalKeyboardKey.f9 => 'F9',
      LogicalKeyboardKey.f10 => 'F10',
      LogicalKeyboardKey.f11 => 'F11',
      LogicalKeyboardKey.f12 => 'F12',
      _ => null,
    };
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
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _line)),
              ),
              child: Text(
                title.toUpperCase(),
                style: _mono(
                  size: 11,
                  color: _ink2,
                  letterSpacing: 1.6,
                  weight: FontWeight.w500,
                ),
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
        Text(
          label,
          style: _sans(size: 13.5, color: _ink0, weight: FontWeight.w500),
        ),
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
  const _Seg({
    required this.value,
    required this.options,
    required this.onChanged,
  });
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: v == value ? _bg0 : null,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: v == value
                      ? [
                          BoxShadow(
                            color: _line2,
                            blurRadius: 0,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: _mono(
                    size: 11,
                    color: v == value ? _ink0 : _ink2,
                    letterSpacing: 0.5,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? _ink0 : _line2,
              width: selected ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
