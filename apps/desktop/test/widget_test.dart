import 'package:flutter_test/flutter_test.dart';

import 'package:tindra_desktop/main.dart';

void main() {
  test('desktop app defaults to dark terminal settings', () {
    expect(appSettings.value.theme, 'dark');
    expect(appSettings.value.fontFamily, isNotEmpty);
    expect(appSettings.value.fontSize, greaterThan(0));
  });
}
