// SPDX-License-Identifier: Apache-2.0
//
// Tindra desktop — Phase 3 with tabs.
// Each tab owns one SSH session (its own snapshot stream, cols/rows, error
// state). Connect creates a new tab; the tab bar at the top of the terminal
// pane lets the user switch between live sessions and close them.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

import 'package:tindra_desktop/l10n/app_localizations.dart';
import 'package:tindra_desktop/src/rust/api/forward.dart' as rust;
import 'package:tindra_desktop/src/rust/api/profiles.dart' as rust;
import 'package:tindra_desktop/src/rust/api/settings.dart' as rust;
import 'package:tindra_desktop/src/rust/api/sftp.dart' as rust;
import 'package:tindra_desktop/src/rust/api/ssh.dart' as rust;
import 'package:tindra_desktop/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await hotKeyManager.unregisterAll();
  await RustLib.init();
  try {
    appSettings.value = await rust.loadSettings();
  } catch (_) {
    // Fall back to the in-code defaults if the file is unreadable.
  }
  await _registerQuakeHotkey();
  appSettings.addListener(_registerQuakeHotkey);
  runApp(const TindraApp());
}

/// Quake-style global hotkey: pressing it from anywhere shows or hides the
/// Tindra window. Re-registers whenever Settings.quakeHotkey changes.
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
    // Hotkey may already be in use by another app — silently fall back.
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

/// Live settings broadcast to the whole widget tree. We use a ValueNotifier
/// in the global [appSettings] so any widget that depends on it (the theme,
/// the terminal style) rebuilds when the user saves new settings.
final ValueNotifier<rust.Settings> appSettings = ValueNotifier(
  const rust.Settings(
    theme: 'dark',
    fontFamily: 'Cascadia Mono',
    fontSize: 13.0,
    quakeHotkey: '',
    locale: 'system',
  ),
);

// ============================================================================
// Phosphor Console — design tokens
// ----------------------------------------------------------------------------
// A retro-futuristic terminal aesthetic: deep teal-black canvas, mint phosphor
// accent, warm amber for liminal states, coral for errors. Brutalist geometry
// (4–12px corners), characterful mono typography, control-panel signaling.
// ============================================================================

class _Pal {
  // Dark
  static const ink = Color(0xFF06100D); // canvas / body bg
  static const inkDeep = Color(0xFF030806); // gradient terminus
  static const surface = Color(0xFF0E1916); // primary panel
  static const surfaceHi = Color(0xFF152521); // raised tiles, tabs
  static const surfaceLo = Color(0xFF0A1411); // recessed wells
  static const divider = Color(0xFF1E332C);
  static const dividerHi = Color(0xFF2B4A41);

  static const phosphor = Color(0xFF7CEAB6); // primary mint
  static const phosphorDim = Color(0xFF49957A);
  static const amber = Color(0xFFFFB069); // connecting / warning
  static const coral = Color(0xFFFF7B6E); // error / disconnected

  static const chalk = Color(0xFFE8F1ED); // primary text
  static const moss = Color(0xFF8AA89C); // secondary text
  static const slate = Color(0xFF5C7A6F); // tertiary text / hint

  // Light (paper terminal)
  static const paper = Color(0xFFF1ECDD);
  static const paperSurface = Color(0xFFFBF7E9);
  static const paperHi = Color(0xFFFFFFFF);
  static const paperInk = Color(0xFF14241F);
  static const paperPhos = Color(0xFF0F6A48);
  static const paperAmber = Color(0xFFB85F1A);
  static const paperCoral = Color(0xFFC23E2D);
  static const paperMoss = Color(0xFF5F7569);
  static const paperDivider = Color(0xFFD9D1B8);
}

bool get _isLight => appSettings.value.theme == 'light';

Color get _bgInk => _isLight ? _Pal.paper : _Pal.ink;
Color get _bgInkDeep => _isLight ? _Pal.paper : _Pal.inkDeep;
Color get _bgSurface => _isLight ? _Pal.paperSurface : _Pal.surface;
Color get _bgSurfaceHi => _isLight ? _Pal.paperHi : _Pal.surfaceHi;
Color get _bgSurfaceLo =>
    _isLight ? const Color(0xFFE8E2CC) : _Pal.surfaceLo;
Color get _divider => _isLight ? _Pal.paperDivider : _Pal.divider;
Color get _dividerHi =>
    _isLight ? const Color(0xFFC9BFA0) : _Pal.dividerHi;

Color get _accent => _isLight ? _Pal.paperPhos : _Pal.phosphor;
Color get _accentDim => _isLight ? const Color(0xFF6FA28C) : _Pal.phosphorDim;
Color get _amber => _isLight ? _Pal.paperAmber : _Pal.amber;
Color get _coral => _isLight ? _Pal.paperCoral : _Pal.coral;

Color get _textHi => _isLight ? _Pal.paperInk : _Pal.chalk;
Color get _textMid => _isLight ? _Pal.paperMoss : _Pal.moss;
Color get _textLow =>
    _isLight ? const Color(0xFF87856E) : _Pal.slate;

Color get _termFg => _textHi;
Color get _termBg => _isLight ? _Pal.paperHi : const Color(0xFF050B09);

const List<String> _terminalFontFallback = [
  'Cascadia Mono',
  'Cascadia Code',
  'D2Coding',
  'Consolas',
  'Malgun Gothic',
  'Noto Sans Mono CJK KR',
];

const List<String> _displayMono = [
  'Cascadia Mono',
  'Cascadia Code',
  'Consolas',
  'Courier New',
];

const List<String> _uiSans = [
  'Segoe UI Variable',
  'Segoe UI',
  'Malgun Gothic',
  'Roboto',
];

TextStyle get _termStyle => TextStyle(
      fontFamily: appSettings.value.fontFamily,
      fontFamilyFallback: _terminalFontFallback,
      fontSize: appSettings.value.fontSize,
      height: 1.35,
      color: _termFg,
    );

TextStyle get _monoLabel => TextStyle(
      fontFamily: 'Cascadia Mono',
      fontFamilyFallback: _displayMono,
      fontSize: 10.5,
      height: 1.0,
      letterSpacing: 1.6,
      fontWeight: FontWeight.w600,
      color: _textMid,
    );

class TindraApp extends StatelessWidget {
  const TindraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<rust.Settings>(
      valueListenable: appSettings,
      builder: (context, settings, child) {
        final isLight = settings.theme == 'light';
        final base = isLight
            ? ThemeData.light(useMaterial3: true)
            : ThemeData.dark(useMaterial3: true);
        final accent = isLight ? _Pal.paperPhos : _Pal.phosphor;
        final scaffold = isLight ? _Pal.paper : _Pal.ink;
        final surface = isLight ? _Pal.paperSurface : _Pal.surface;
        final ink = isLight ? _Pal.paperInk : _Pal.chalk;
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
            scaffoldBackgroundColor: scaffold,
            colorScheme: isLight
                ? const ColorScheme.light(
                    primary: _Pal.paperPhos,
                    onPrimary: Colors.white,
                    secondary: _Pal.paperAmber,
                    surface: _Pal.paperSurface,
                    onSurface: _Pal.paperInk,
                    error: _Pal.paperCoral,
                  )
                : const ColorScheme.dark(
                    primary: _Pal.phosphor,
                    onPrimary: _Pal.ink,
                    secondary: _Pal.amber,
                    surface: _Pal.surface,
                    onSurface: _Pal.chalk,
                    error: _Pal.coral,
                  ),
            textTheme: base.textTheme.apply(
              bodyColor: ink,
              displayColor: ink,
              fontFamily: 'Segoe UI Variable',
              fontFamilyFallback: _uiSans,
            ),
            dividerColor: isLight ? _Pal.paperDivider : _Pal.divider,
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: false,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
            ),
            iconTheme: IconThemeData(
              color: isLight ? _Pal.paperMoss : _Pal.moss,
              size: 18,
            ),
            tooltipTheme: TooltipThemeData(
              textStyle: TextStyle(
                color: isLight ? _Pal.paperInk : _Pal.chalk,
                fontFamily: 'Cascadia Mono',
                fontFamilyFallback: _displayMono,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
              decoration: BoxDecoration(
                color: isLight
                    ? _Pal.paperHi
                    : const Color(0xFF1A2925),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isLight ? _Pal.paperDivider : _Pal.dividerHi,
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: isLight
                  ? const Color(0xFFEDE7D2)
                  : const Color(0xFF0B1714),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: isLight ? _Pal.paperDivider : _Pal.divider,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: isLight ? _Pal.paperDivider : _Pal.divider,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: accent, width: 1.4),
              ),
              hintStyle: TextStyle(
                color: isLight ? _Pal.paperMoss : _Pal.slate,
                fontFamily: 'Cascadia Mono',
                fontFamilyFallback: _displayMono,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: isLight ? Colors.white : _Pal.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Cascadia Mono',
                  fontFamilyFallback: _displayMono,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  fontSize: 12.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                side: BorderSide(
                  color: isLight ? _Pal.paperDivider : _Pal.dividerHi,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Cascadia Mono',
                  fontFamilyFallback: _displayMono,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  fontSize: 12,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: isLight ? _Pal.paperMoss : _Pal.moss,
                textStyle: const TextStyle(
                  fontFamily: 'Cascadia Mono',
                  fontFamilyFallback: _displayMono,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: isLight ? _Pal.paperDivider : _Pal.dividerHi,
                ),
              ),
              titleTextStyle: TextStyle(
                fontFamily: 'Cascadia Mono',
                fontFamilyFallback: _displayMono,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                fontSize: 13,
                color: ink,
              ),
            ),
            dropdownMenuTheme: DropdownMenuThemeData(
              menuStyle: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(
                  isLight ? _Pal.paperHi : const Color(0xFF152521),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(
                      color: isLight ? _Pal.paperDivider : _Pal.dividerHi,
                    ),
                  ),
                ),
              ),
            ),
            sliderTheme: SliderThemeData(
              activeTrackColor: accent,
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.12),
              inactiveTrackColor:
                  isLight ? _Pal.paperDivider : _Pal.divider,
              valueIndicatorColor: accent,
              valueIndicatorTextStyle: TextStyle(
                color: isLight ? Colors.white : _Pal.ink,
                fontFamily: 'Cascadia Mono',
                fontFamilyFallback: _displayMono,
                fontWeight: FontWeight.w700,
              ),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? (isLight ? Colors.white : _Pal.ink)
                    : (isLight ? _Pal.paperMoss : _Pal.moss),
              ),
              trackColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? accent
                    : (isLight ? _Pal.paperDivider : _Pal.divider),
              ),
            ),
            segmentedButtonTheme: SegmentedButtonThemeData(
              style: SegmentedButton.styleFrom(
                backgroundColor: isLight
                    ? const Color(0xFFEDE7D2)
                    : const Color(0xFF0B1714),
                foregroundColor: isLight ? _Pal.paperInk : _Pal.chalk,
                selectedBackgroundColor: accent,
                selectedForegroundColor:
                    isLight ? Colors.white : _Pal.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Cascadia Mono',
                  fontFamilyFallback: _displayMono,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          home: const ShellScreen(),
        );
      },
    );
  }
}

/// The Tindra brand mark: a sealed terminal viewport — corner brackets
/// framing a phosphor `>_` prompt with a softly pulsing cursor block. The
/// pulse is deliberately slow (1.4s) so it reads as a heartbeat, not an
/// attention-grabber.
class _TindraMark extends StatefulWidget {
  const _TindraMark({this.size = 32});
  final double size;

  @override
  State<_TindraMark> createState() => _TindraMarkState();
}

class _TindraMarkState extends State<_TindraMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _TindraMarkPainter(
              accent: _accent,
              accentDim: _accentDim,
              ink: _isLight
                  ? const Color(0xFFD9D1B8)
                  : const Color(0xFF0B1714),
              cursorOpacity:
                  Curves.easeInOut.transform(_ctl.value) * 0.7 + 0.3,
            ),
          ),
        );
      },
    );
  }
}

class _TindraMarkPainter extends CustomPainter {
  _TindraMarkPainter({
    required this.accent,
    required this.accentDim,
    required this.ink,
    required this.cursorOpacity,
  });

  final Color accent;
  final Color accentDim;
  final Color ink;
  final double cursorOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Inner viewport
    final viewport = RRect.fromLTRBR(
      w * 0.06,
      h * 0.06,
      w * 0.94,
      h * 0.94,
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(viewport, Paint()..color = ink);

    // Corner brackets (viewfinder)
    final bracket = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.square;
    final pad = w * 0.14;
    final arm = w * 0.18;
    // top-left
    canvas.drawLine(Offset(pad, pad), Offset(pad + arm, pad), bracket);
    canvas.drawLine(Offset(pad, pad), Offset(pad, pad + arm), bracket);
    // top-right
    canvas.drawLine(Offset(w - pad, pad), Offset(w - pad - arm, pad), bracket);
    canvas.drawLine(Offset(w - pad, pad), Offset(w - pad, pad + arm), bracket);
    // bottom-left
    canvas.drawLine(Offset(pad, h - pad), Offset(pad + arm, h - pad), bracket);
    canvas.drawLine(Offset(pad, h - pad), Offset(pad, h - pad - arm), bracket);
    // bottom-right
    canvas.drawLine(
        Offset(w - pad, h - pad), Offset(w - pad - arm, h - pad), bracket);
    canvas.drawLine(
        Offset(w - pad, h - pad), Offset(w - pad, h - pad - arm), bracket);

    // > chevron prompt
    final prompt = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;
    final p = Path()
      ..moveTo(w * 0.34, h * 0.40)
      ..lineTo(w * 0.48, h * 0.50)
      ..lineTo(w * 0.34, h * 0.60);
    canvas.drawPath(p, prompt);

    // cursor block (pulsing)
    final cursor = Paint()
      ..color = accent.withValues(alpha: cursorOpacity);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.54, h * 0.46, w * 0.16, w * 0.10),
      cursor,
    );

    // soft outer glow
    final glow = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
    canvas.drawRRect(viewport, glow);
  }

  @override
  bool shouldRepaint(covariant _TindraMarkPainter old) =>
      old.cursorOpacity != cursorOpacity ||
      old.accent != accent ||
      old.ink != ink;
}

/// Background painter: deep gradient + faint dot grid + radial vignette.
class _PhosphorBackground extends StatelessWidget {
  const _PhosphorBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PhosphorBackgroundPainter(
        ink: _bgInk,
        inkDeep: _bgInkDeep,
        dot: _isLight
            ? _Pal.paperDivider.withValues(alpha: 0.5)
            : const Color(0xFF12251F),
        accentTint: _accent.withValues(alpha: _isLight ? 0.04 : 0.05),
      ),
      child: child,
    );
  }
}

class _PhosphorBackgroundPainter extends CustomPainter {
  _PhosphorBackgroundPainter({
    required this.ink,
    required this.inkDeep,
    required this.dot,
    required this.accentTint,
  });

  final Color ink;
  final Color inkDeep;
  final Color dot;
  final Color accentTint;

  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient: top-left ink -> bottom-right inkDeep
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [ink, inkDeep],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    // Phosphor wash from upper-left
    final wash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.6, -0.7),
        radius: 1.4,
        colors: [accentTint, Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    // Faint 24px dot grid
    final dotPaint = Paint()..color = dot;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PhosphorBackgroundPainter old) =>
      old.ink != ink || old.dot != dot;
}

/// `▌ LABEL` style section header used throughout the sidebar.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.trailing});
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Row(
        children: [
          Container(width: 3, height: 11, color: _accent),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: _monoLabel,
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Pulsing status LED: 6×6 dot with halo. Pulses only while connecting.
class _StatusLED extends StatefulWidget {
  const _StatusLED({required this.color, required this.pulsing, this.size = 6});
  final Color color;
  final bool pulsing;
  final double size;

  @override
  State<_StatusLED> createState() => _StatusLEDState();
}

class _StatusLEDState extends State<_StatusLED>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _ctl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StatusLED old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_ctl.isAnimating) {
      _ctl.repeat(reverse: true);
    } else if (!widget.pulsing && _ctl.isAnimating) {
      _ctl.stop();
      _ctl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, _) {
        final intensity =
            widget.pulsing ? (0.45 + Curves.easeInOut.transform(_ctl.value) * 0.55) : 1.0;
        return SizedBox(
          width: widget.size + 8,
          height: widget.size + 8,
          child: Center(
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: intensity),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.45 * intensity),
                    blurRadius: 6,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Corner brackets framing the terminal viewport.
class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: CustomPaint(
          size: Size.infinite,
          painter: _CornerBracketPainter(color: color, arm: 14),
        ),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  _CornerBracketPainter({required this.color, required this.arm});
  final Color color;
  final double arm;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final w = size.width;
    final h = size.height;
    // tl
    canvas.drawLine(const Offset(0, 0), Offset(arm, 0), p);
    canvas.drawLine(const Offset(0, 0), Offset(0, arm), p);
    // tr
    canvas.drawLine(Offset(w, 0), Offset(w - arm, 0), p);
    canvas.drawLine(Offset(w, 0), Offset(w, arm), p);
    // bl
    canvas.drawLine(Offset(0, h), Offset(arm, h), p);
    canvas.drawLine(Offset(0, h), Offset(0, h - arm), p);
    // br
    canvas.drawLine(Offset(w, h), Offset(w - arm, h), p);
    canvas.drawLine(Offset(w, h), Offset(w, h - arm), p);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter old) =>
      old.color != color;
}

/// Optional scanline overlay on the terminal panel — very low contrast,
/// ignored on light theme. Does not interfere with hit-testing.
class _ScanlineOverlay extends StatelessWidget {
  const _ScanlineOverlay();

  @override
  Widget build(BuildContext context) {
    if (_isLight) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScanlinePainter(),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x06000000);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _ConnState { connecting, connected, disconnected }

const String _localShellProfileId = '__local_shell__';

/// One live (or recently-live) SSH session. Held inside _ShellScreenState's
/// `_tabs` list; the State is a thin shell around mutable fields here so
/// setState on the outer widget rebuilds with the right tab.
class _SessionTab {
  _SessionTab({required this.profileId, required this.profileName});

  final String profileId;
  final String profileName;

  BigInt? sessionId;
  _ConnState state = _ConnState.connecting;
  rust.TerminalSnapshot? snapshot;
  StreamSubscription<rust.TerminalSnapshot>? outputSub;
  String? error;

  // Geometry last reported to the remote PTY for THIS session.
  int cols = 120;
  int rows = 32;
  Timer? resizeDebounce;

  Future<void> dispose() async {
    resizeDebounce?.cancel();
    final id = sessionId;
    sessionId = null;
    // Tell Rust to drop its StreamSink first so the Dart subscription will
    // see `done` and unblock. If we cancel the subscription first, frb 2.x
    // awaits the Rust task to acknowledge the cancel, but that task is
    // blocked reading from the SSH channel — deadlock.
    if (id != null) {
      try {
        await rust.shellClose(sessionId: id);
      } catch (_) {}
    }
    // The cancel will complete on its own once the stream emits done; don't
    // block UI close on it.
    final sub = outputSub;
    outputSub = null;
    sub?.cancel();
  }
}

/// One tab in the bar. May host multiple sessions in a horizontal or
/// vertical split (Phase 8a). MVP keeps the split linear: sessions are a
/// flat list and the tab's split axis applies between every neighbour.
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

  // Tab state — each tab is a group of one or more sessions in a split.
  final List<_TabGroup> _tabs = [];
  int _activeIdx = -1;

  // Sidebar-only error (separate from per-tab error)
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B2C2C),
              ),
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
      tab.outputSub = rust.shellOutputStream(sessionId: id).listen(
        (snap) {
          tab.snapshot = snap;
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

  Future<void> _openLocalShell() async {
    final tab = _SessionTab(
      profileId: _localShellProfileId,
      profileName: 'Local Shell',
    );
    setState(() {
      _tabs.add(_TabGroup(profileName: 'Local Shell', first: tab));
      _activeIdx = _tabs.length - 1;
    });
    await _connectLocalIntoExistingSession(tab);
  }

  Future<void> _connectLocalIntoExistingSession(_SessionTab tab) async {
    try {
      final id = await rust.openLocalShell(
        shell: null,
        cols: tab.cols,
        rows: tab.rows,
      );
      tab.sessionId = id;
      tab.outputSub = rust.shellOutputStream(sessionId: id).listen(
        (snap) {
          tab.snapshot = snap;
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

  Future<void> _connectIntoExistingSession(
    rust.Profile p,
    _SessionTab tab,
  ) async {
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
      tab.outputSub = rust.shellOutputStream(sessionId: id).listen(
        (snap) {
          tab.snapshot = snap;
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
    if (_activeGroup == null || _selectedProfile == null) return;
    await _connectSelected(
        splitInto: _activeGroup, axis: Axis.horizontal);
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
    // shellClose first so the Rust StreamSink drops; otherwise cancelling
    // the Dart subscription deadlocks waiting for the Rust task to ack.
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

  // ---------------------- Terminal I/O for active tab ----------------------

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
      // Reserved app-level shortcuts: leave unhandled so Shortcuts/Actions
      // can pick them up.
      final shift = HardwareKeyboard.instance.isShiftPressed;
      if (logical == LogicalKeyboardKey.keyT ||
          logical == LogicalKeyboardKey.keyW ||
          logical == LogicalKeyboardKey.tab ||
          logical == LogicalKeyboardKey.comma ||
          (shift &&
              (logical == LogicalKeyboardKey.keyC ||
                  logical == LogicalKeyboardKey.keyH ||
                  logical == LogicalKeyboardKey.keyR ||
                  logical == LogicalKeyboardKey.keyV ||
                  logical == LogicalKeyboardKey.keyE))) {
        return null;
      }
      // Flutter often reports null/empty `character` for Ctrl+letter on
      // desktop, so map physical logical keys directly. This makes terminal
      // essentials like Ctrl+C (ETX), Ctrl+D (EOT), Ctrl+Z (SUB) reliable.
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

  @override
  void dispose() {
    for (final t in _tabs) {
      t.dispose();
    }
    _passphrase.dispose();
    _termFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = _activeTab;
    final l10n = AppLocalizations.of(context);
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyT, control: true):
            const _NewTabIntent(),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            const _CloseTabIntent(),
        const SingleActivator(LogicalKeyboardKey.tab, control: true):
            const _NextTabIntent(),
        const SingleActivator(LogicalKeyboardKey.tab,
            control: true, shift: true): const _PrevTabIntent(),
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            const _SettingsIntent(),
        const SingleActivator(LogicalKeyboardKey.keyH,
            control: true, shift: true): const _SplitHorizontalIntent(),
        const SingleActivator(LogicalKeyboardKey.keyE,
            control: true, shift: true): const _SplitVerticalIntent(),
        const SingleActivator(LogicalKeyboardKey.keyC,
            control: true, shift: true): const _CopyScreenIntent(),
        const SingleActivator(LogicalKeyboardKey.keyV,
            control: true, shift: true): const _PasteClipboardIntent(),
        const SingleActivator(LogicalKeyboardKey.keyR,
            control: true, shift: true): const _ReconnectIntent(),
      },
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
              _openSettingsDialog();
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
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: _PhosphorBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    _topBar(l10n, tab),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 308, child: _sidePanel()),
                            const SizedBox(width: 16),
                            Expanded(child: _terminalArea()),
                          ],
                        ),
                      ),
                    ),
                    _statusBar(tab),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openForwardDialog(rust.Profile profile) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ForwardDialog(profile: profile),
    );
  }

  Future<void> _openSftpDialog(rust.Profile profile) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SftpDialog(profile: profile),
    );
  }

  Future<void> _openSettingsDialog() async {
    final result = await showDialog<rust.Settings>(
      context: context,
      builder: (_) => _SettingsDialog(initial: appSettings.value),
    );
    if (result == null) return;
    try {
      await rust.saveSettings(settings: result);
      appSettings.value = result;
    } catch (e) {
      if (mounted) setState(() => _sidebarError = e.toString());
    }
  }

  Future<void> _openHostKeysDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _HostKeysDialog(),
    );
  }

  // ---------------------- Top bar & status bar ----------------------

  Widget _topBar(AppLocalizations l10n, _SessionTab? tab) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          const _TindraMark(size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TINDRA',
                style: TextStyle(
                  fontFamily: 'Cascadia Mono',
                  fontFamilyFallback: _displayMono,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 7,
                  color: _textHi,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(width: 14, height: 1, color: _accent),
                  const SizedBox(width: 6),
                  Text(
                    'PHOSPHOR · v0.1',
                    style: TextStyle(
                      fontFamily: 'Cascadia Mono',
                      fontFamilyFallback: _displayMono,
                      fontSize: 9.5,
                      letterSpacing: 2.4,
                      color: _textLow,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 28),
          if (tab != null) _sessionBreadcrumb(tab),
          const Spacer(),
          _topAction(
            icon: Icons.copy_outlined,
            tooltip: l10n.copyScreenTooltip,
            onTap: _activeTab?.snapshot == null ? null : _copyScreen,
          ),
          _topAction(
            icon: Icons.content_paste_outlined,
            tooltip: l10n.pasteClipboardTooltip,
            onTap: _activeTab?.state == _ConnState.connected
                ? _pasteClipboard
                : null,
          ),
          _topAction(
            icon: Icons.replay_outlined,
            tooltip: l10n.reconnectTooltip,
            onTap: _activeTab == null ? null : _reconnectActive,
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 22, color: _divider),
          const SizedBox(width: 8),
          _topAction(
            icon: Icons.verified_outlined,
            tooltip: l10n.trustedHostKeys,
            onTap: _openHostKeysDialog,
          ),
          _topAction(
            icon: Icons.tune,
            tooltip: l10n.settingsTooltip,
            onTap: _openSettingsDialog,
          ),
        ],
      ),
    );
  }

  Widget _sessionBreadcrumb(_SessionTab tab) {
    final stateColor = switch (tab.state) {
      _ConnState.connecting => _amber,
      _ConnState.connected => _accent,
      _ConnState.disconnected => _coral,
    };
    final label = switch (tab.state) {
      _ConnState.connecting => 'CONNECTING',
      _ConnState.connected => 'LIVE',
      _ConnState.disconnected => 'OFFLINE',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bgSurfaceLo,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusLED(
            color: stateColor,
            pulsing: tab.state == _ConnState.connecting,
            size: 6,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cascadia Mono',
              fontFamilyFallback: _displayMono,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: stateColor,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 12, color: _divider),
          const SizedBox(width: 10),
          Text(
            tab.profileName,
            style: TextStyle(
              fontFamily: 'Cascadia Mono',
              fontFamilyFallback: _displayMono,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textHi,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.transparent),
            ),
            child: Icon(
              icon,
              size: 17,
              color: enabled
                  ? _textMid
                  : _textLow.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBar(_SessionTab? tab) {
    final s = tab?.snapshot;
    final transport = (() {
      if (tab == null) return '—';
      if (tab.profileId == _localShellProfileId) return 'LOCAL';
      final p = _profileById(tab.profileId);
      return (p?.transport ?? 'ssh').toUpperCase();
    })();
    final stateLabel = switch (tab?.state) {
      null => 'IDLE',
      _ConnState.connecting => 'HANDSHAKE',
      _ConnState.connected => 'READY',
      _ConnState.disconnected => 'CLOSED',
    };
    final grid = s != null ? '${s.cols}×${s.rows}' : '—';
    final cursor = s != null ? '${s.cursorRow},${s.cursorCol}' : '—';
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: _bgSurfaceLo,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          _statusChip('TRX', transport),
          _statusChip('STATE', stateLabel),
          _statusChip('GRID', grid),
          _statusChip('CUR', cursor),
          const Spacer(),
          _statusChip('SESSIONS', '${_tabs.length}'),
          _statusChip('FONT',
              '${appSettings.value.fontFamily} · ${appSettings.value.fontSize.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _statusChip(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            key,
            style: TextStyle(
              fontFamily: 'Cascadia Mono',
              fontFamilyFallback: _displayMono,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: _accentDim,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cascadia Mono',
              fontFamilyFallback: _displayMono,
              fontSize: 11,
              color: _textMid,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------- Sidebar ----------------------

  Widget _sidePanel() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSurface.withValues(alpha: _isLight ? 0.92 : 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(
            l10n.profiles,
            trailing: _miniIconButton(
              icon: Icons.add,
              tooltip: l10n.newProfile,
              onTap: () => _openProfileDialog(),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _bgSurfaceLo,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _divider),
              ),
              child: _profilesLoading
                  ? Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: _accent,
                        ),
                      ),
                    )
                  : _profiles.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _profiles.length,
                          itemBuilder: (_, i) => _profileTile(_profiles[i]),
                        ),
            ),
          ),
          const SizedBox(height: 12),
          _ghostButton(
            icon: Icons.terminal,
            label: l10n.openLocalShell,
            onTap: _openLocalShell,
          ),
          if (_selectedProfile != null) ...[
            const SizedBox(height: 14),
            _SectionLabel('CONSOLE'),
            _connectionActions(_selectedProfile!),
          ],
          if (_sidebarError != null) ...[
            const SizedBox(height: 12),
            _errorBox(
              _sidebarError!,
              onClose: () => setState(() => _sidebarError = null),
            ),
          ],
          if (_activeTab?.error != null) ...[
            const SizedBox(height: 12),
            _errorBox(
              _activeTab!.error!,
              onClose: () => setState(() => _activeTab!.error = null),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            border: Border.all(color: _dividerHi),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(icon, size: 14, color: _textMid),
        ),
      ),
    );
  }

  Widget _ghostButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? accentTint,
  }) {
    final tint = accentTint ?? _textMid;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _bgSurfaceLo,
          border: Border.all(color: _dividerHi),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: tint),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cascadia Mono',
                fontFamilyFallback: _displayMono,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: _textHi,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 14, color: _textLow),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String msg, {required VoidCallback onClose}) {
    return Container(
      decoration: BoxDecoration(
        color: _isLight
            ? const Color(0xFFFCEDE9)
            : const Color(0xFF1F100F),
        border: Border.all(color: _coral.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 8),
            child: Icon(Icons.error_outline, size: 14, color: _coral),
          ),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: _isLight ? _Pal.paperCoral : const Color(0xFFFFB6AC),
                fontFamily: 'Cascadia Mono',
                fontFamilyFallback: _displayMono,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(3),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: _coral),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                border: Border.all(color: _dividerHi),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Icon(Icons.lan_outlined, size: 24, color: _textMid),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '— NO HOSTS REGISTERED —',
              style: TextStyle(
                fontFamily: 'Cascadia Mono',
                fontFamilyFallback: _displayMono,
                fontSize: 9.5,
                letterSpacing: 1.6,
                color: _textLow,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.noProfilesYet,
              style: TextStyle(color: _textMid, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _openProfileDialog(),
              icon: const Icon(Icons.add, size: 14),
              label: Text(l10n.createOne.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileTile(rust.Profile p) {
    final selected = p.id == _selectedProfileId;
    final monogram = _monogramFor(p);
    final transport = (p.transport.isEmpty ? 'ssh' : p.transport).toUpperCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedProfileId = p.id),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 9, 12, 9),
          decoration: BoxDecoration(
            color: selected
                ? (_isLight
                    ? _accent.withValues(alpha: 0.10)
                    : _accent.withValues(alpha: 0.06))
                : null,
            border: Border(
              left: BorderSide(
                color: selected ? _accent : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(
                color: _divider.withValues(alpha: 0.6),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _bgSurfaceHi,
                  border: Border.all(color: _dividerHi),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Center(
                  child: Text(
                    monogram,
                    style: TextStyle(
                      fontFamily: 'Cascadia Mono',
                      fontFamilyFallback: _displayMono,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: selected ? _accent : _textMid,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.name.isEmpty ? '(unnamed)' : p.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _textHi,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _dividerHi,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            transport,
                            style: TextStyle(
                              fontFamily: 'Cascadia Mono',
                              fontFamilyFallback: _displayMono,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: _textLow,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${p.username}@${p.host}${p.port == 22 ? "" : ":${p.port}"}',
                      style: TextStyle(
                        fontFamily: 'Cascadia Mono',
                        fontFamilyFallback: _displayMono,
                        fontSize: 10.5,
                        color: _textMid,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monogramFor(rust.Profile p) {
    final source = p.name.trim().isNotEmpty
        ? p.name.trim()
        : (p.host.trim().isNotEmpty ? p.host.trim() : '?');
    final parts = source
        .replaceAll(RegExp(r'[^A-Za-z0-9 .\-_]'), '')
        .split(RegExp(r'[\s.\-_]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    final s = parts.isEmpty ? source : parts[0];
    return s.length >= 2
        ? s.substring(0, 2).toUpperCase()
        : s.toUpperCase().padRight(1);
  }

  Widget _connectionActions(rust.Profile p) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: _bgSurfaceLo,
            border: Border.all(color: _divider),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name.isEmpty ? p.host : p.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textHi,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${p.username}@${p.host}${p.port == 22 ? "" : ":${p.port}"}',
                style: TextStyle(
                  fontFamily: 'Cascadia Mono',
                  fontFamilyFallback: _displayMono,
                  fontSize: 11,
                  color: _accent,
                  letterSpacing: 0.3,
                ),
              ),
              if (p.transport == 'ssh' && p.authMethod == 'key') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _passphrase,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: l10n.keyPassphraseHint,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 4),
                      child:
                          Icon(Icons.key_outlined, size: 14, color: _textLow),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 26, minHeight: 26),
                  ),
                  style: TextStyle(
                    fontFamily: 'Cascadia Mono',
                    fontFamilyFallback: _displayMono,
                    fontSize: 11.5,
                    color: _textHi,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _connectSelected,
          icon: const Icon(Icons.bolt, size: 16),
          label: Text('OPEN ${p.name.toUpperCase()}'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size.fromHeight(0),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openProfileDialog(existing: p),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: Text(l10n.edit.toUpperCase()),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: _coral,
                side: BorderSide(color: _coral.withValues(alpha: 0.45)),
              ),
              onPressed: () => _deleteProfile(p),
              child: const Icon(Icons.delete_outline, size: 16),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        _ghostButton(
          icon: Icons.folder_shared_outlined,
          label: l10n.sftpBrowser.toUpperCase(),
          onTap: () => _openSftpDialog(p),
        ),
        const SizedBox(height: 6),
        _ghostButton(
          icon: Icons.cable_outlined,
          label: l10n.portForwards.toUpperCase(),
          onTap: () => _openForwardDialog(p),
        ),
      ],
    );
  }

  // ---------------------- Terminal area (tab bar + active terminal) ----------------------

  Widget _terminalArea() {
    return Container(
      decoration: BoxDecoration(
        color: _bgSurface.withValues(alpha: _isLight ? 0.92 : 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabBar(),
          Expanded(child: _terminalPanel()),
        ],
      ),
    );
  }

  Widget _tabBar() {
    final l10n = AppLocalizations.of(context);
    if (_tabs.isEmpty) {
      return Container(
        height: 38,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _divider),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Container(width: 3, height: 14, color: _accentDim),
            const SizedBox(width: 8),
            Text(
              l10n.noOpenSessions.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Cascadia Mono',
                fontFamilyFallback: _displayMono,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                color: _textLow,
              ),
            ),
            const Spacer(),
            Tooltip(
              message: _selectedProfile == null
                  ? l10n.pickProfileToOpen
                  : l10n.openSelectedProfile(_selectedProfile!.name),
              child: InkWell(
                onTap:
                    _selectedProfile == null ? null : _connectSelected,
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: _dividerHi),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 12, color: _textMid),
                      const SizedBox(width: 4),
                      Text(
                        'NEW',
                        style: TextStyle(
                          fontFamily: 'Cascadia Mono',
                          fontFamilyFallback: _displayMono,
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                          color: _textMid,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length + 1,
        itemBuilder: (_, i) {
          if (i == _tabs.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
              child: Tooltip(
                message: _selectedProfile == null
                    ? l10n.pickProfileToOpen
                    : l10n.openSelectedProfile(_selectedProfile!.name),
                child: InkWell(
                  onTap: _selectedProfile == null ? null : _connectSelected,
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    width: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: _dividerHi),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Icon(Icons.add, size: 14, color: _textMid),
                  ),
                ),
              ),
            );
          }
          return _tab(i);
        },
      ),
    );
  }

  Widget _tab(int i) {
    final group = _tabs[i];
    final active = i == _activeIdx;
    final stateColor = switch (group.active.state) {
      _ConnState.connecting => _amber,
      _ConnState.connected => _accent,
      _ConnState.disconnected => _coral,
    };
    return Padding(
      padding: const EdgeInsets.only(right: 1),
      child: SizedBox(
        height: 38,
        child: Stack(
          children: [
            Material(
              color: active ? _bgSurfaceHi : Colors.transparent,
              child: InkWell(
                onTap: () => _switchTab(i),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusLED(
                        color: stateColor,
                        pulsing: group.active.state == _ConnState.connecting,
                        size: 6,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        group.sessions.length > 1
                            ? '${group.profileName} ·${group.sessions.length}'
                            : group.profileName,
                        style: TextStyle(
                          fontFamily: 'Cascadia Mono',
                          fontFamilyFallback: _displayMono,
                          fontSize: 11.5,
                          letterSpacing: 0.4,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? _textHi : _textMid,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        key: ValueKey('tab-close-$i'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _closeTab(i),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: active ? _textMid : _textLow,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (active)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 2, color: _accent),
              ),
            // subtle right divider between tabs
            Positioned(
              right: 0,
              top: 8,
              bottom: 8,
              child: Container(width: 1, color: _divider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitView({required double charWidth, required double lineHeight}) {
    final group = _activeGroup;
    if (group == null || group.sessions.isEmpty) {
      return _CellGrid(
        tab: null,
        isFocused: _termFocus.hasFocus,
        charWidth: charWidth,
        lineHeight: lineHeight,
        onDisconnect: _disconnectActive,
      );
    }
    if (group.sessions.length == 1) {
      return _CellGrid(
        tab: group.sessions.first,
        isFocused: _termFocus.hasFocus,
        charWidth: charWidth,
        lineHeight: lineHeight,
        onDisconnect: _disconnectActive,
      );
    }
    final children = <Widget>[];
    for (var i = 0; i < group.sessions.length; i++) {
      final isActive = i == group.activeIdx;
      children.add(Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            group.activeIdx = i;
            _termFocus.requestFocus();
          }),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isActive ? _accent : _divider,
                width: isActive ? 1.4 : 1,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(6),
            child: _CellGrid(
              tab: group.sessions[i],
              isFocused: isActive && _termFocus.hasFocus,
              charWidth: charWidth,
              lineHeight: lineHeight,
              onDisconnect: _disconnectActive,
            ),
          ),
        ),
      ));
    }
    return group.splitAxis == Axis.horizontal
        ? Row(children: children)
        : Column(children: children);
  }

  Widget _terminalPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          // Inner viewport with the terminal background colour and a thin
          // phosphor-tinted hairline.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _termBg,
                border: Border.all(color: _dividerHi),
                borderRadius: BorderRadius.circular(2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
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
                          text: TextSpan(text: 'M', style: _termStyle),
                          textDirection: TextDirection.ltr,
                        )..layout();
                        final charWidth = probe.width;
                        final lineHeight = probe.height;
                        probe.dispose();

                        const padding = 14.0;
                        final availW = constraints.maxWidth - padding * 2;
                        final availH = constraints.maxHeight - padding * 2;
                        final fitCols =
                            (availW / charWidth).floor().clamp(20, 400);
                        final fitRows =
                            (availH / lineHeight).floor().clamp(8, 200);

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scheduleResize(fitCols, fitRows);
                        });

                        return Padding(
                          padding: const EdgeInsets.all(padding),
                          child: _splitView(
                            charWidth: charWidth,
                            lineHeight: lineHeight,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Subtle scanline overlay (dark theme only)
          const Positioned.fill(child: _ScanlineOverlay()),
          // Viewfinder corner brackets
          Positioned.fill(
            child: _CornerBrackets(
              color: _accent.withValues(alpha: _isLight ? 0.55 : 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _CellGrid extends StatelessWidget {
  const _CellGrid({
    required this.tab,
    required this.isFocused,
    required this.charWidth,
    required this.lineHeight,
    required this.onDisconnect,
  });

  final _SessionTab? tab;
  final bool isFocused;
  final double charWidth;
  final double lineHeight;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    if (tab == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '◇ NO ACTIVE SESSION ◇',
              style: TextStyle(
                fontFamily: 'Cascadia Mono',
                fontFamilyFallback: _displayMono,
                fontSize: 10,
                letterSpacing: 2,
                color: _textLow,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).pickProfilePrompt,
              style: TextStyle(color: _textMid, fontSize: 12),
            ),
          ],
        ),
      );
    }
    final t = tab!;
    if (t.state == _ConnState.connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: _amber,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '— HANDSHAKE —',
              style: TextStyle(
                fontFamily: 'Cascadia Mono',
                fontFamilyFallback: _displayMono,
                fontSize: 10,
                letterSpacing: 2,
                color: _amber,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).connectingTo(t.profileName),
              style: TextStyle(color: _textMid, fontSize: 12),
            ),
          ],
        ),
      );
    }
    if (t.state == _ConnState.disconnected && t.snapshot == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 28, color: _coral),
            const SizedBox(height: 10),
            Text(
              '— LINK DOWN —',
              style: TextStyle(
                fontFamily: 'Cascadia Mono',
                fontFamilyFallback: _displayMono,
                fontSize: 10,
                letterSpacing: 2,
                color: _coral,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).disconnected,
              style: TextStyle(color: _textMid, fontSize: 12),
            ),
          ],
        ),
      );
    }
    final s = t.snapshot;
    if (s == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).waitingForFirstChunk,
          style: TextStyle(color: _textMid, fontSize: 12),
        ),
      );
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
        if (s.cursorVisible && t.state == _ConnState.connected)
          Positioned(
            left: s.cursorCol * charWidth,
            top: s.cursorRow * lineHeight,
            width: charWidth,
            height: lineHeight,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: isFocused
                      ? _accent.withValues(alpha: 0.55)
                      : _accent.withValues(alpha: 0.18),
                  border: isFocused
                      ? null
                      : Border.all(
                          color: _accent.withValues(alpha: 0.65),
                          width: 1,
                        ),
                ),
              ),
            ),
          ),
        if (t.state == _ConnState.disconnected)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _coral.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_outlined,
                        size: 11, color: _isLight ? Colors.white : _Pal.ink),
                    const SizedBox(width: 4),
                    Text(
                      'OFFLINE',
                      style: TextStyle(
                        fontFamily: 'Cascadia Mono',
                        fontFamilyFallback: _displayMono,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: _isLight ? Colors.white : _Pal.ink,
                      ),
                    ),
                  ],
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
    fontFamily: appSettings.value.fontFamily,
    fontFamilyFallback: _terminalFontFallback,
    fontSize: appSettings.value.fontSize,
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
    _key = TextEditingController(
        text: p?.privateKeyPath ?? r'C:\Users\XIU\.ssh\id_ed25519');
    _notes = TextEditingController(text: p?.notes ?? '');
    _jumpHost = TextEditingController(text: p?.jumpHost ?? '');
    _jumpPort = TextEditingController(
        text: ((p?.jumpPort ?? 0) == 0 ? 22 : p!.jumpPort).toString());
    _jumpUser = TextEditingController(text: p?.jumpUsername ?? '');
    _jumpKey = TextEditingController(text: p?.jumpPrivateKeyPath ?? '');
    _authMethod =
        (p?.authMethod.isEmpty ?? true) ? 'key' : p!.authMethod;
    _showJump = (p?.jumpHost.isNotEmpty ?? false);
    _transport = (p?.transport.isEmpty ?? true) ? 'ssh' : p!.transport;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _host,
      _port,
      _user,
      _key,
      _notes,
      _jumpHost,
      _jumpPort,
      _jumpUser,
      _jumpKey,
    ]) {
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
    return AlertDialog(
      backgroundColor: const Color(0xFF161A22),
      title: Text(isNew ? l10n.newProfile : l10n.editProfile),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(l10n.name, _name, hint: 'e.g. prod-web-1'),
              _row(l10n.host, _host, hint: 'localhost / 1.2.3.4 / dev.example.com'),
              Row(children: [
                Expanded(child: _row(l10n.user, _user, hint: 'XIU')),
                const SizedBox(width: 8),
                SizedBox(width: 100, child: _row(l10n.port, _port)),
              ]),
              _transportPicker(),
              if (_transport == 'ssh') ...[
                _authMethodPicker(),
                if (_authMethod == 'key') _row(l10n.privateKeyPath, _key),
              ],
              _jumpSection(),
              _row(l10n.notes, _notes, hint: l10n.optional, maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _host.text.trim().isEmpty || _user.text.trim().isEmpty
              ? null
              : _save,
          child: Text(isNew ? l10n.create : l10n.save),
        ),
      ],
    );
  }

  Widget _transportPicker() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(l10n.transport,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8AA0B5))),
          ),
          DropdownButtonFormField<String>(
            initialValue: _transport,
            items: [
              DropdownMenuItem(value: 'ssh', child: Text(l10n.ssh)),
              DropdownMenuItem(value: 'telnet', child: Text(l10n.telnetRawTcp)),
            ],
            onChanged: (v) => setState(() => _transport = v ?? 'ssh'),
          ),
        ],
      ),
    );
  }

  Widget _jumpSection() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(l10n.jumpHost,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8AA0B5))),
            ),
            const Spacer(),
            Switch(
              value: _showJump,
              onChanged: (v) => setState(() => _showJump = v),
            ),
          ]),
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

  Widget _authMethodPicker() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(l10n.auth,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8AA0B5))),
          ),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'key',
                  label: Text(l10n.privateKey),
                ),
                ButtonSegment<String>(
                  value: 'agent',
                  label: Text(l10n.sshAgent),
                ),
              ],
              selected: {_authMethod},
              onSelectionChanged: (v) =>
                  setState(() => _authMethod = v.firstOrNull ?? 'key'),
            ),
          ),
        ],
      ),
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

// ---------------------- Phase 5 — port-forward dialog ----------------------

class _ForwardDialog extends StatefulWidget {
  const _ForwardDialog({required this.profile});
  final rust.Profile profile;

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
  List<rust.PortForward> _forwards = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _localAddr.dispose();
    _localPort.dispose();
    _remoteHost.dispose();
    _remotePort.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final list = await rust.listForwards();
    if (mounted) setState(() => _forwards = list);
  }

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
      await _refresh();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop(rust.PortForward f) async {
    await rust.stopForward(id: f.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Port forwards — ${widget.profile.name}'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add a local forward (-L)',
                style: TextStyle(
                    fontSize: 12, color: Color(0xFF8AA0B5))),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _localAddr,
                      decoration:
                          const InputDecoration(hintText: 'Local addr'))),
              const SizedBox(width: 8),
              SizedBox(
                  width: 90,
                  child: TextField(
                      controller: _localPort,
                      decoration:
                          const InputDecoration(hintText: 'Port'))),
            ]),
            const SizedBox(height: 6),
            const Icon(Icons.south, size: 14),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _remoteHost,
                      decoration: const InputDecoration(
                          hintText: 'Remote host (relative to SSH server)'))),
              const SizedBox(width: 8),
              SizedBox(
                  width: 90,
                  child: TextField(
                      controller: _remotePort,
                      decoration:
                          const InputDecoration(hintText: 'Port'))),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _open,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Open forward'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFFFB4B4), fontSize: 12)),
            ],
            const Divider(height: 24),
            Row(children: [
              const Expanded(
                child: Text('Active forwards',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF8AA0B5))),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: _refresh,
              ),
            ]),
            const SizedBox(height: 4),
            if (_forwards.isEmpty)
              const Text('(none)',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF8AA0B5)))
            else
              ..._forwards.map((f) => _row(f)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }

  Widget _row(rust.PortForward f) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(
          child: Text(
            '${f.localAddr}:${f.localPort} → ${f.remoteHost}:${f.remotePort}',
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          tooltip: 'Stop',
          onPressed: () => _stop(f),
        ),
      ]),
    );
  }
}

// ---------------------- Phase 6 — SFTP browser ----------------------

class _SftpDialog extends StatefulWidget {
  const _SftpDialog({required this.profile});
  final rust.Profile profile;

  @override
  State<_SftpDialog> createState() => _SftpDialogState();
}

class _SftpDialogState extends State<_SftpDialog> {
  BigInt? _sessionId;
  String? _error;
  bool _busy = false;

  String _localPath =
      Platform.environment['USERPROFILE'] ?? Directory.current.path;
  String _remotePath = '';
  List<FileSystemEntity> _localEntries = [];
  List<rust.SftpEntry> _remoteEntries = [];
  FileSystemEntity? _selectedLocal;
  rust.SftpEntry? _selectedRemote;

  @override
  void initState() {
    super.initState();
    _connect();
    _refreshLocal();
  }

  Future<void> _connect() async {
    final p = widget.profile;
    setState(() => _busy = true);
    try {
      final jump = rust.JumpHost(
        host: p.jumpHost,
        port: p.jumpPort == 0 ? 22 : p.jumpPort,
        username: p.jumpUsername,
        privateKeyPath: p.jumpPrivateKeyPath,
        passphrase: null,
      );
      final id = p.authMethod == 'agent'
          ? await rust.openSftpAgent(
              host: p.host,
              port: p.port,
              username: p.username,
              jump: jump,
            )
          : await rust.openSftpPubkey(
              host: p.host,
              port: p.port,
              username: p.username,
              privateKeyPath: p.privateKeyPath,
              passphrase: null,
              jump: jump,
            );
      _sessionId = id;
      _remotePath = await rust.sftpHome(sessionId: id);
      await _refreshRemote();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refreshLocal() {
    try {
      final dir = Directory(_localPath);
      final entries = dir.listSync()
        ..sort((a, b) {
          final ad = a is Directory;
          final bd = b is Directory;
          if (ad != bd) return ad ? -1 : 1;
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });
      setState(() {
        _localEntries = entries;
        _selectedLocal = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _refreshRemote() async {
    final id = _sessionId;
    if (id == null) return;
    try {
      final list = await rust.sftpList(sessionId: id, path: _remotePath);
      setState(() {
        _remoteEntries = list;
        _selectedRemote = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _navigateLocal(FileSystemEntity entity) {
    if (entity is Directory) {
      _localPath = entity.path;
      _refreshLocal();
    } else {
      setState(() => _selectedLocal = entity);
    }
  }

  Future<void> _navigateRemote(rust.SftpEntry entry) async {
    if (entry.isDir) {
      _remotePath = _joinRemote(_remotePath, entry.name);
      await _refreshRemote();
    } else {
      setState(() => _selectedRemote = entry);
    }
  }

  String _joinRemote(String base, String name) {
    if (base.endsWith('/')) return '$base$name';
    return '$base/$name';
  }

  Future<void> _localUp() async {
    final parent = Directory(_localPath).parent.path;
    if (parent != _localPath) {
      _localPath = parent;
      _refreshLocal();
    }
  }

  Future<void> _remoteUp() async {
    final idx = _remotePath.lastIndexOf('/');
    if (idx > 0) {
      _remotePath = _remotePath.substring(0, idx);
      await _refreshRemote();
    } else if (idx == 0 && _remotePath.length > 1) {
      _remotePath = '/';
      await _refreshRemote();
    }
  }

  Future<void> _doUpload() async {
    final id = _sessionId;
    final local = _selectedLocal;
    if (id == null || local is! File) return;
    setState(() => _busy = true);
    try {
      final fileName = local.uri.pathSegments.last;
      await rust.sftpUpload(
        sessionId: id,
        localPath: local.path,
        remotePath: _joinRemote(_remotePath, fileName),
      );
      await _refreshRemote();
      _flash('Uploaded $fileName');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doDownload() async {
    final id = _sessionId;
    final remote = _selectedRemote;
    if (id == null || remote == null || remote.isDir) return;
    setState(() => _busy = true);
    try {
      final localTarget = '$_localPath${Platform.pathSeparator}${remote.name}';
      await rust.sftpDownload(
        sessionId: id,
        remotePath: _joinRemote(_remotePath, remote.name),
        localPath: localTarget,
      );
      _refreshLocal();
      _flash('Downloaded ${remote.name}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _flash(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    final id = _sessionId;
    _sessionId = null;
    if (id != null) {
      // fire and forget
      rust.sftpClose(sessionId: id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: SizedBox(
        width: 1100,
        height: 700,
        child: Column(
          children: [
            AppBar(
              title: Text('SFTP — ${widget.profile.name}'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (_error != null)
              Container(
                color: const Color(0xFF2A1417),
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                child: Row(children: [
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: Color(0xFFFFB4B4))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    onPressed: () => setState(() => _error = null),
                  ),
                ]),
              ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _localPanel()),
                  _transferControls(),
                  Expanded(child: _remotePanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transferControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filled(
            tooltip: 'Upload (local → remote)',
            onPressed:
                (_selectedLocal is File && _sessionId != null && !_busy)
                    ? _doUpload
                    : null,
            icon: const Icon(Icons.arrow_forward),
          ),
          const SizedBox(height: 12),
          IconButton.filled(
            tooltip: 'Download (remote → local)',
            onPressed: (_selectedRemote != null &&
                    !(_selectedRemote!.isDir) &&
                    _sessionId != null &&
                    !_busy)
                ? _doDownload
                : null,
            icon: const Icon(Icons.arrow_back),
          ),
        ],
      ),
    );
  }

  Widget _localPanel() {
    return _panel(
      title: 'Local',
      path: _localPath,
      onUp: _localUp,
      onRefresh: _refreshLocal,
      child: ListView.builder(
        itemCount: _localEntries.length,
        itemBuilder: (_, i) {
          final e = _localEntries[i];
          final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
          final isDir = e is Directory;
          final selected = identical(e, _selectedLocal);
          return ListTile(
            dense: true,
            selected: selected,
            leading: Icon(
              isDir ? Icons.folder : Icons.insert_drive_file_outlined,
              size: 18,
            ),
            title: Text(name, style: const TextStyle(fontSize: 13)),
            onTap: () => _navigateLocal(e),
          );
        },
      ),
    );
  }

  Widget _remotePanel() {
    return _panel(
      title: 'Remote',
      path: _remotePath.isEmpty ? '(connecting…)' : _remotePath,
      onUp: _sessionId == null ? null : _remoteUp,
      onRefresh: _sessionId == null ? null : _refreshRemote,
      child: _sessionId == null
          ? const Center(child: Text('Not connected'))
          : ListView.builder(
              itemCount: _remoteEntries.length,
              itemBuilder: (_, i) {
                final e = _remoteEntries[i];
                final selected = identical(e, _selectedRemote);
                return ListTile(
                  dense: true,
                  selected: selected,
                  leading: Icon(
                    e.isDir
                        ? Icons.folder
                        : (e.isSymlink
                            ? Icons.link
                            : Icons.insert_drive_file_outlined),
                    size: 18,
                  ),
                  title: Text(e.name, style: const TextStyle(fontSize: 13)),
                  trailing: e.isDir
                      ? null
                      : Text('${e.size}',
                          style: const TextStyle(fontSize: 11)),
                  onTap: () => _navigateRemote(e),
                );
              },
            ),
    );
  }

  Widget _panel({
    required String title,
    required String path,
    required Widget child,
    VoidCallback? onUp,
    VoidCallback? onRefresh,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1F2937)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
            child: Row(children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8AA0B5))),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 16),
                tooltip: 'Up',
                onPressed: onUp,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                tooltip: 'Refresh',
                onPressed: onRefresh,
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(path,
                style: const TextStyle(
                    fontFamily: 'Consolas', fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ---------------------- Phase 7 — shortcuts and settings ----------------------

class _NewTabIntent extends Intent {
  const _NewTabIntent();
}

class _CloseTabIntent extends Intent {
  const _CloseTabIntent();
}

class _NextTabIntent extends Intent {
  const _NextTabIntent();
}

class _PrevTabIntent extends Intent {
  const _PrevTabIntent();
}

class _SettingsIntent extends Intent {
  const _SettingsIntent();
}

class _SplitHorizontalIntent extends Intent {
  const _SplitHorizontalIntent();
}

class _SplitVerticalIntent extends Intent {
  const _SplitVerticalIntent();
}

class _CopyScreenIntent extends Intent {
  const _CopyScreenIntent();
}

class _PasteClipboardIntent extends Intent {
  const _PasteClipboardIntent();
}

class _ReconnectIntent extends Intent {
  const _ReconnectIntent();
}


class _HostKeysDialog extends StatefulWidget {
  const _HostKeysDialog();

  @override
  State<_HostKeysDialog> createState() => _HostKeysDialogState();
}

class _HostKeysDialogState extends State<_HostKeysDialog> {
  late Future<List<rust.HostKey>> _future;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = rust.listHostKeys();
  }

  void _reload() {
    setState(() {
      _error = null;
      _future = rust.listHostKeys();
    });
  }

  String _fmt(BuildContext context, BigInt ms) {
    final value = ms.toInt();
    if (value <= 0) return AppLocalizations.of(context).unknown;
    return DateTime.fromMillisecondsSinceEpoch(value).toLocal().toString();
  }

  Future<void> _delete(rust.HostKey key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.removeTrustedHostKeyQuestion),
          content: Text(l10n.removeTrustedHostKeyContent(key.host, key.port)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B2C2C),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.remove),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await rust.deleteHostKey(host: key.host, port: key.port);
      _reload();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.trustedHostKeys),
      content: SizedBox(
        width: 680,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.trustedHostKeysDescription,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8AA0B5)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFFFB4B4))),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<rust.HostKey>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text(snap.error.toString()));
                  }
                  final keys = snap.data ?? const [];
                  if (keys.isEmpty) {
                    return Center(
                      child: Text(l10n.noTrustedHostKeys),
                    );
                  }
                  return ListView.separated(
                    itemCount: keys.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final k = keys[i];
                      return ListTile(
                        title: Text('${k.host}:${k.port}'),
                        subtitle: Text(
                          '${k.fingerprint}\n'
                          '${l10n.firstSeen}: ${_fmt(context, k.firstSeenUnixMs)}    '
                          '${l10n.lastSeen}: ${_fmt(context, k.lastSeenUnixMs)}',
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 12,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.removeTrustedKeyTooltip,
                          onPressed: () => _delete(k),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(l10n.refresh),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.initial});
  final rust.Settings initial;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late String _theme;
  late final TextEditingController _fontFamily;
  late double _fontSize;
  late final TextEditingController _quakeHotkey;
  late String _locale;

  @override
  void initState() {
    super.initState();
    _theme = widget.initial.theme.isEmpty ? 'dark' : widget.initial.theme;
    _fontFamily = TextEditingController(text: widget.initial.fontFamily);
    _fontSize = widget.initial.fontSize > 0 ? widget.initial.fontSize : 13.0;
    _quakeHotkey = TextEditingController(text: widget.initial.quakeHotkey);
    _locale = widget.initial.locale.isEmpty ? 'system' : widget.initial.locale;
  }

  @override
  void dispose() {
    _fontFamily.dispose();
    _quakeHotkey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.settings),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l10n.language,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8AA0B5))),
            ),
            DropdownButtonFormField<String>(
              initialValue: _locale,
              items: [
                DropdownMenuItem(value: 'system', child: Text(l10n.systemLanguage)),
                DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                DropdownMenuItem(value: 'ko', child: Text(l10n.korean)),
              ],
              onChanged: (v) => setState(() => _locale = v ?? 'system'),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l10n.theme,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8AA0B5))),
            ),
            DropdownButtonFormField<String>(
              initialValue: _theme,
              items: [
                DropdownMenuItem(value: 'dark', child: Text(l10n.dark)),
                DropdownMenuItem(value: 'light', child: Text(l10n.light)),
              ],
              onChanged: (v) => setState(() => _theme = v ?? 'dark'),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l10n.terminalFont,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8AA0B5))),
            ),
            TextField(
              controller: _fontFamily,
              decoration: const InputDecoration(
                hintText: 'D2Coding, Cascadia Mono, Consolas, ...',
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Text(l10n.size(_fontSize.toStringAsFixed(0)),
                  style: const TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 9,
                  max: 24,
                  divisions: 15,
                  label: _fontSize.toStringAsFixed(0),
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l10n.quakeGlobalHotkey,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8AA0B5))),
            ),
            TextField(
              controller: _quakeHotkey,
              decoration: InputDecoration(
                hintText: l10n.quakeHotkeyHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              rust.Settings(
                theme: _theme,
                fontFamily: _fontFamily.text.trim().isEmpty
                    ? 'Consolas'
                    : _fontFamily.text.trim(),
                fontSize: _fontSize,
                quakeHotkey: _quakeHotkey.text.trim(),
                locale: _locale,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
