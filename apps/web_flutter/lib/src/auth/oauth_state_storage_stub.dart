String? _expectedState;

void storeOAuthState(String state) {
  _expectedState = state;
}

bool consumeOAuthState(String state) {
  final matches = _expectedState == state;
  _expectedState = null;
  return matches;
}

void clearOAuthState() {
  _expectedState = null;
}
