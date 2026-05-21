import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindra_desktop/l10n/app_localizations.dart';
import 'package:tindra_desktop/main.dart';

void main() {
  testWidgets('host-key changed content shows old and new fingerprints', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HostKeyDecisionDetails(
            host: 'example.com',
            port: 22,
            status: 'changed',
            expected: 'SHA256:old',
            actual: 'SHA256:new',
          ),
        ),
      ),
    );

    final text = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    expect(text, contains('example.com:22'));
    expect(text, contains('SHA256:old'));
    expect(text, contains('SHA256:new'));
  });

  test('password auth hides the private key field policy', () {
    expect(shouldShowPrivateKeyFieldForAuthMethod('key'), isTrue);
    expect(shouldShowPrivateKeyFieldForAuthMethod('agent'), isFalse);
    expect(shouldShowPrivateKeyFieldForAuthMethod('password'), isFalse);
  });

  test('pending connection tabs are discarded only for user cancellation', () {
    expect(
      shouldDiscardPendingConnectionTab(
        userCanceled: true,
        hasSessionId: false,
      ),
      isTrue,
    );
    expect(
      shouldDiscardPendingConnectionTab(
        userCanceled: false,
        hasSessionId: false,
      ),
      isFalse,
    );
    expect(
      shouldDiscardPendingConnectionTab(
        userCanceled: true,
        hasSessionId: true,
      ),
      isFalse,
    );
  });

  testWidgets('Korean localization covers quick connect shell strings', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(l10n.favorite, '즐겨찾기');
    expect(l10n.favorites, '즐겨찾기');
    expect(l10n.recent, '최근');
    expect(l10n.noSession, '세션 없음');
    expect(l10n.noDetachableSession, '분리할 연결된 세션이 없습니다.');
    expect(l10n.openLink, '링크 열기');
  });
}
