// Phase 0 smoke test — verifies the Rust-Dart bridge round-trips.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tindra_desktop/main.dart';
import 'package:tindra_desktop/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  testWidgets('Hello-world UI calls into Rust core', (tester) async {
    await tester.pumpWidget(const TindraApp());
    expect(
      find.textContaining('Tindra core says: hello from Flutter'),
      findsOneWidget,
    );
    expect(find.textContaining('tindra-core'), findsOneWidget);
  });
}
