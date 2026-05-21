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

  test('connection timeout errors are recognized for UI mapping', () {
    expect(
      isConnectionTimeoutError('connection timed out after 20 seconds'),
      isTrue,
    );
    expect(isConnectionTimeoutError('permission denied'), isFalse);
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
    expect(l10n.connectionTimedOut, '연결 시간이 20초를 초과했습니다.');
    expect(l10n.cancelConnection, '연결 취소');
  });

  testWidgets('shell error banner displays and can be dismissed', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShellErrorBanner(
            message: 'profile save failed',
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    expect(find.text('profile save failed'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(dismissed, isTrue);
  });

  testWidgets('profile connection choice row shows name and endpoint', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProfileConnectionChoiceRow(
            name: 'oci-osaka-1',
            endpoint: 'xiu@oci-osaka-1:22',
            authMethod: 'key',
            accent: Colors.lightBlueAccent,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('oci-osaka-1'), findsOneWidget);
    expect(find.text('xiu@oci-osaka-1:22'), findsOneWidget);
    expect(find.text('key'), findsOneWidget);

    await tester.tap(find.byType(ProfileConnectionChoiceRow));
    expect(tapped, isTrue);
  });
}
