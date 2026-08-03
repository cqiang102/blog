// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

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
  // 使用 package:web（dart:js_interop）实现，兼容 Wasm 构建；
  // 不再依赖 Wasm 不可用的 dart:html。
  web.EventListener? _pasteListener;

  @override
  void initState() {
    super.initState();
    _pasteListener = _handlePaste.toJS;
    web.document.addEventListener('paste', _pasteListener);
  }

  @override
  void dispose() {
    if (_pasteListener != null) {
      web.document.removeEventListener('paste', _pasteListener);
    }
    super.dispose();
  }

  void _handlePaste(web.Event event) {
    if (!widget.focusNode.hasFocus) return;
    final clipboardEvent = event as web.ClipboardEvent;
    final items = clipboardEvent.clipboardData?.items;
    if (items == null) return;

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final mimeType = item.type;
      if (item.kind != 'file' || !mimeType.startsWith('image/')) continue;

      final file = item.getAsFile();
      if (file == null) continue;
      event.preventDefault();
      unawaited(_readImageFile(file, mimeType));
      return;
    }
  }

  Future<void> _readImageFile(web.File file, String mimeType) async {
    try {
      final buffer = (await file.arrayBuffer().toDart).toDart;
      if (!mounted) return;
      widget.onImage(
        PastedMarkdownImage(
          bytes: Uint8List.view(buffer),
          filename: file.name.isEmpty
              ? 'pasted-image.${_extensionForMimeType(mimeType)}'
              : file.name,
          mimeType: mimeType,
        ),
      );
    } catch (_) {
      // 剪贴板图片读取失败时静默忽略，不影响编辑器。
    }
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
