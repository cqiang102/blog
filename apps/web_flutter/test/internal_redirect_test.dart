import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/router/internal_redirect.dart';

void main() {
  test('preserves valid internal paths with query parameters', () {
    expect(safeInternalRedirect('/admin?tab=comments'), '/admin?tab=comments');
  });

  test('rejects absolute and protocol-relative URLs', () {
    expect(safeInternalRedirect('https://example.com/admin'), '/profile');
    expect(safeInternalRedirect('//example.com/admin'), '/profile');
  });

  test('rejects malformed, relative, and traversal paths', () {
    expect(safeInternalRedirect('admin'), '/profile');
    expect(safeInternalRedirect('/admin/%ZZ'), '/profile');
    expect(safeInternalRedirect('/admin/../profile'), '/profile');
    expect(safeInternalRedirect('/admin\\profile'), '/profile');
  });
}
