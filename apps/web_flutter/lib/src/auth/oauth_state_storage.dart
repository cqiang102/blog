import 'oauth_state_storage_stub.dart'
    if (dart.library.js_interop) 'oauth_state_storage_web.dart'
    if (dart.library.io) 'oauth_state_storage_io.dart'
    as impl;

void storeOAuthState(String state) => impl.storeOAuthState(state);

bool consumeOAuthState(String state) => impl.consumeOAuthState(state);

void clearOAuthState() => impl.clearOAuthState();
