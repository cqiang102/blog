import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/sse/sse_parser.dart';

void main() {
  test('parseSseBlock preserves token whitespace', () {
    final events = parseSseBlock('event: token\ndata:  hello  \n\n');

    expect(events, hasLength(1));
    expect(events.single.type, 'token');
    expect(events.single.data, ' hello  ');
  });

  test('parseSseBlock treats empty token data as newline', () {
    final events = parseSseBlock('event: token\ndata:\n\n');

    expect(events, hasLength(1));
    expect(events.single.type, 'token');
    expect(events.single.data, '\n');
  });
}
