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
}
