import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/auth/oauth_state_storage.dart';

void main() {
  tearDown(clearOAuthState);

  test('OAuth state is consumed only once', () {
    storeOAuthState('expected');

    expect(consumeOAuthState('expected'), isTrue);
    expect(consumeOAuthState('expected'), isFalse);
  });

  test('a mismatched attempt also clears the expected state', () {
    storeOAuthState('expected');

    expect(consumeOAuthState('wrong'), isFalse);
    expect(consumeOAuthState('expected'), isFalse);
  });
}
