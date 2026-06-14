import 'package:web/web.dart' as web;

const _storageKey = 'auth.oauth.expectedState';

void storeOAuthState(String state) {
  web.window.sessionStorage.setItem(_storageKey, state);
}

bool consumeOAuthState(String state) {
  final expected = web.window.sessionStorage.getItem(_storageKey);
  web.window.sessionStorage.removeItem(_storageKey);
  return expected == state;
}

void clearOAuthState() {
  web.window.sessionStorage.removeItem(_storageKey);
}
