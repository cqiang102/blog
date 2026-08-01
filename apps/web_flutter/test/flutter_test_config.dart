import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(bytes);
}

Future<void> _loadFontFamily(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(_fontData(path));
  }
  await loader.load();
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Flutter's deterministic Ahem test font does not contain CJK glyphs.
  // Register compact test-only subsets under the first production fallback
  // families so Golden output exercises real Chinese glyph metrics.
  await Future.wait([
    _loadFontFamily('system-ui', const [
      'test/fonts/NotoSansSC-Golden-400.ttf',
      'test/fonts/NotoSansSC-Golden-700.ttf',
    ]),
    _loadFontFamily('monospace', const [
      'test/fonts/NotoSansSC-Golden-400.ttf',
      'test/fonts/NotoSansSC-Golden-700.ttf',
    ]),
    _loadFontFamily('Songti SC', const [
      'test/fonts/NotoSerifSC-Golden-700.ttf',
    ]),
  ]);

  await testMain();
}
