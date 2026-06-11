import 'package:flutter_test/flutter_test.dart';

import 'package:personal_blog_web/src/core/media_url.dart';

void main() {
  test('builds a stable media file reference', () {
    expect(
      mediaFileReference('ef3b99a0-ecb2-4607-b980-7f56df39cee5'),
      '/api/v1/media-assets/ef3b99a0-ecb2-4607-b980-7f56df39cee5/file',
    );
  });

  test('resolves API media references against the configured API origin', () {
    expect(
      resolveMediaUrl(
        '/api/v1/media-assets/ef3b99a0-ecb2-4607-b980-7f56df39cee5/file',
      ),
      'http://localhost:8080/api/v1/media-assets/'
      'ef3b99a0-ecb2-4607-b980-7f56df39cee5/file',
    );
  });

  test('keeps external URLs unchanged', () {
    const url = 'https://cdn.example.com/photo.png';
    expect(resolveMediaUrl(url), url);
  });
}
