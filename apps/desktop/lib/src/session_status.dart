enum SessionVisualState { connecting, connected, disconnected }

String sessionStatusLabel(SessionVisualState state) {
  switch (state) {
    case SessionVisualState.connecting:
      return 'connecting';
    case SessionVisualState.connected:
      return 'connected';
    case SessionVisualState.disconnected:
      return 'disconnected';
  }
}

bool canPasteToSession(SessionVisualState state) {
  return state == SessionVisualState.connected;
}

bool canDisconnectSession(SessionVisualState state) {
  return state == SessionVisualState.connected;
}

bool canReconnectSession(SessionVisualState state) {
  return state != SessionVisualState.connecting;
}
