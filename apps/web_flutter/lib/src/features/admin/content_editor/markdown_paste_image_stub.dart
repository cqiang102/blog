import 'dart:typed_data';

import 'package:flutter/widgets.dart';

class PastedMarkdownImage {
  const PastedMarkdownImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

class MarkdownPasteImageListener extends StatelessWidget {
  const MarkdownPasteImageListener({
    super.key,
    required this.focusNode,
    required this.onImage,
    required this.child,
  });

  final FocusNode focusNode;
  final ValueChanged<PastedMarkdownImage> onImage;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
