import 'package:flutter_test/flutter_test.dart';
import 'package:tindra_desktop/src/session_status.dart';

void main() {
  test('session status labels are stable user-facing strings', () {
    expect(sessionStatusLabel(SessionVisualState.connecting), 'connecting');
    expect(sessionStatusLabel(SessionVisualState.connected), 'connected');
    expect(sessionStatusLabel(SessionVisualState.disconnected), 'disconnected');
  });

  test('session toolbar actions are enabled only for valid states', () {
    expect(canPasteToSession(SessionVisualState.connected), isTrue);
    expect(canPasteToSession(SessionVisualState.disconnected), isFalse);
    expect(canDisconnectSession(SessionVisualState.connected), isTrue);
    expect(canDisconnectSession(SessionVisualState.connecting), isFalse);
    expect(canReconnectSession(SessionVisualState.disconnected), isTrue);
    expect(canReconnectSession(SessionVisualState.connecting), isFalse);
  });
}
