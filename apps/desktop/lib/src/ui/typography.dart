part of '../../main.dart';

const _uiFontFallback = [
  'Inter',
  'Segoe UI',
  'Malgun Gothic',
  'Apple SD Gothic Neo',
  'Noto Sans CJK KR',
  'Noto Sans KR',
  'Arial',
];

const _monoFontFallback = [
  'JetBrains Mono',
  'Cascadia Mono',
  'Consolas',
  'D2Coding',
  'Malgun Gothic',
  'Noto Sans Mono CJK KR',
  'Courier New',
];

TextStyle _display({
  double size = 36,
  FontWeight weight = FontWeight.w500,
  Color? color,
  double letterSpacing = 0,
}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    height: 1.05,
    letterSpacing: letterSpacing,
    color: color ?? _ink0,
  ).copyWith(fontFamilyFallback: _uiFontFallback);
}

TextStyle _sans({
  double size = 13.5,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double letterSpacing = 0,
}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    height: 1.4,
    letterSpacing: letterSpacing,
    color: color ?? _ink0,
  ).copyWith(fontFamilyFallback: _uiFontFallback);
}

TextStyle _mono({
  double size = 12,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double letterSpacing = 0,
}) {
  return GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    height: 1.4,
    letterSpacing: letterSpacing,
    color: color ?? _ink1,
  ).copyWith(fontFamilyFallback: _monoFontFallback);
}

TextStyle _eyebrow() =>
    _mono(size: 10.5, weight: FontWeight.w500, color: _acc, letterSpacing: 1.5);

TextStyle _blockHead() =>
    _mono(size: 11, weight: FontWeight.w500, color: _ink1, letterSpacing: 1.6);

TextStyle _blockSub() => _mono(size: 11, color: _ink3, letterSpacing: 0.4);

TextStyle get _termStyle {
  final fam = appSettings.value.fontFamily;
  final size = appSettings.value.fontSize <= 0
      ? 13.0
      : appSettings.value.fontSize;
  if (fam.isEmpty || fam.toLowerCase().contains('jetbrains')) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      height: 1.55,
      color: _tFg,
    ).copyWith(fontFamilyFallback: _monoFontFallback);
  }
  return TextStyle(
    fontFamily: fam,
    fontFamilyFallback: _monoFontFallback,
    fontSize: size,
    height: 1.55,
    color: _tFg,
  );
}
