import 'package:flutter_test/flutter_test.dart';
import 'package:tindra_desktop/l10n/app_localizations_en.dart';
import 'package:tindra_desktop/l10n/app_localizations_ko.dart';

void main() {
  test('Korean localizations expose readable Korean UI strings', () {
    final l10n = AppLocalizationsKo();

    expect(l10n.profiles, '프로필');
    expect(l10n.settings, '설정');
    expect(l10n.openLocalShell, '로컬 셸 열기');
    expect(l10n.disconnected, '연결 끊김');
    expect(l10n.liveSessionsSummary(3, 2), '활성 세션 2개 · 프로필 3개 · 로컬 작업 공간 준비됨');
  });

  test(
    'English live session summary keeps profile and session counts in order',
    () {
      final l10n = AppLocalizationsEn();

      expect(
        l10n.liveSessionsSummary(3, 2),
        '2 live sessions | 3 profiles | local workspace ready',
      );
    },
  );
}
