// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
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

class MarkdownPasteImageListener extends StatefulWidget {
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
  State<MarkdownPasteImageListener> createState() =>
      _MarkdownPasteImageListenerState();
}

class _MarkdownPasteImageListenerState
    extends State<MarkdownPasteImageListener> {
  late final StreamSubscription<html.Event> _pasteSubscription;

  @override
  void initState() {
    super.initState();
    _pasteSubscription = html.document.onPaste.listen(_handlePaste);
  }

  @override
  void dispose() {
    _pasteSubscription.cancel();
    super.dispose();
  }

  void _handlePaste(html.Event event) {
    if (!widget.focusNode.hasFocus) return;
    final clipboardEvent = event as html.ClipboardEvent;
    final items = clipboardEvent.clipboardData?.items;
    if (items == null) return;

    for (var index = 0; index < (items.length ?? 0); index++) {
      final item = items[index];
      final mimeType = item.type ?? '';
      if (item.kind != 'file' || !mimeType.startsWith('image/')) continue;

      final file = item.getAsFile();
      if (file == null) continue;
      event.preventDefault();
      _readImageFile(file, mimeType);
      return;
    }
  }

  void _readImageFile(html.File file, String mimeType) {
    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      if (!mounted) return;
      final result = reader.result;
      if (result is! ByteBuffer) return;

      widget.onImage(
        PastedMarkdownImage(
          bytes: Uint8List.view(result),
          filename: file.name.isEmpty
              ? 'pasted-image.${_extensionForMimeType(mimeType)}'
              : file.name,
          mimeType: mimeType,
        ),
      );
    });
    reader.readAsArrayBuffer(file);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String _extensionForMimeType(String mimeType) {
  return switch (mimeType.toLowerCase()) {
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/jpeg' || 'image/jpg' => 'jpg',
    _ => 'png',
  };
}
