import 'package:flutter/material.dart';

class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  String? _lastText;
  TextSpan? _lastSpan;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final currentText = text;
    if (currentText == _lastText && _lastSpan != null) {
      return _lastSpan!;
    }

    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final scheme = Theme.of(context).colorScheme;
    var children = _highlightMarkdownText(currentText, baseStyle, scheme);
    if (withComposing && value.isComposingRangeValid) {
      children = _applyComposingUnderline(children, value.composing);
    }
    final span = TextSpan(style: baseStyle, children: children);

    _lastText = currentText;
    _lastSpan = span;
    return span;
  }
}

List<TextSpan> _applyComposingUnderline(
  List<TextSpan> spans,
  TextRange composing,
) {
  final result = <TextSpan>[];
  var documentOffset = 0;

  for (final span in spans) {
    final text = span.text ?? '';
    final spanStart = documentOffset;
    final spanEnd = spanStart + text.length;
    final composingStart = composing.start.clamp(spanStart, spanEnd).toInt();
    final composingEnd = composing.end.clamp(spanStart, spanEnd).toInt();

    if (composingStart >= composingEnd) {
      result.add(span);
    } else {
      final localStart = composingStart - spanStart;
      final localEnd = composingEnd - spanStart;
      if (localStart > 0) {
        result.add(
          TextSpan(text: text.substring(0, localStart), style: span.style),
        );
      }
      result.add(
        TextSpan(
          text: text.substring(localStart, localEnd),
          style: (span.style ?? const TextStyle()).copyWith(
            decoration: TextDecoration.underline,
          ),
        ),
      );
      if (localEnd < text.length) {
        result.add(TextSpan(text: text.substring(localEnd), style: span.style));
      }
    }
    documentOffset = spanEnd;
  }

  return result;
}

List<TextSpan> _highlightMarkdownText(
  String text,
  TextStyle baseStyle,
  ColorScheme scheme,
) {
  if (text.isEmpty) return const [TextSpan(text: '')];

  final spans = <TextSpan>[];
  String? openCodeFence;
  final lines = text.split('\n');

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final fenceMatch = RegExp(r'^(\s*)(```|~~~)(.*)$').firstMatch(line);

    final fenceMarker = fenceMatch?.group(2)?[0];
    if (fenceMatch != null &&
        (openCodeFence == null || openCodeFence == fenceMarker)) {
      spans.add(
        TextSpan(
          text: line,
          style: baseStyle.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      openCodeFence = openCodeFence == null ? fenceMarker : null;
    } else if (openCodeFence != null) {
      spans.add(
        TextSpan(
          text: line,
          style: baseStyle.copyWith(
            color: scheme.onSurfaceVariant,
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: 0.72,
            ),
            fontFamily: 'monospace',
          ),
        ),
      );
    } else {
      spans.addAll(_highlightMarkdownLine(line, baseStyle, scheme));
    }

    if (index < lines.length - 1) {
      spans.add(const TextSpan(text: '\n'));
    }
  }

  return spans;
}

List<TextSpan> _highlightMarkdownLine(
  String line,
  TextStyle baseStyle,
  ColorScheme scheme,
) {
  final heading = RegExp(r'^(#{1,6})(\s+.*)$').firstMatch(line);
  if (heading != null) {
    return [
      TextSpan(
        text: heading.group(1),
        style: baseStyle.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
      TextSpan(
        text: heading.group(2),
        style: baseStyle.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
  }

  final blockquote = RegExp(r'^(\s*>)(\s?.*)$').firstMatch(line);
  if (blockquote != null) {
    return [
      TextSpan(
        text: blockquote.group(1),
        style: baseStyle.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      TextSpan(
        text: blockquote.group(2),
        style: baseStyle.copyWith(color: scheme.onSurfaceVariant),
      ),
    ];
  }

  final list = RegExp(
    r'^(\s*(?:- \[[ xX]\]|[-*+]|\d+\.)\s+)(.*)$',
  ).firstMatch(line);
  if (list != null) {
    return [
      TextSpan(
        text: list.group(1),
        style: baseStyle.copyWith(
          color: scheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
      ..._highlightInlineMarkdown(list.group(2) ?? '', baseStyle, scheme),
    ];
  }

  return _highlightInlineMarkdown(line, baseStyle, scheme);
}

List<TextSpan> _highlightInlineMarkdown(
  String text,
  TextStyle baseStyle,
  ColorScheme scheme,
) {
  final spans = <TextSpan>[];
  final pattern = RegExp(
    r'(`[^`]+`)|(\*\*[^*]+\*\*)|(~~[^~]+~~)|(\*[^*]+\*)|(!\[[^\]]*\]\([^)]+\))|(\[[^\]]+\]\([^)]+\))',
  );
  var cursor = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }

    final token = match.group(0)!;
    spans.add(
      TextSpan(text: token, style: _inlineTokenStyle(token, baseStyle, scheme)),
    );
    cursor = match.end;
  }

  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }

  return spans;
}

TextStyle _inlineTokenStyle(
  String token,
  TextStyle baseStyle,
  ColorScheme scheme,
) {
  if (token.startsWith('`')) {
    return baseStyle.copyWith(
      color: scheme.tertiary,
      backgroundColor: scheme.surfaceContainerHighest,
      fontFamily: 'monospace',
    );
  }
  if (token.startsWith('**')) {
    return baseStyle.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w800,
    );
  }
  if (token.startsWith('~~')) {
    return baseStyle.copyWith(
      color: scheme.onSurfaceVariant,
      decoration: TextDecoration.lineThrough,
    );
  }
  if (token.startsWith('*')) {
    return baseStyle.copyWith(
      color: scheme.onSurface,
      fontStyle: FontStyle.italic,
    );
  }
  if (token.startsWith('![')) {
    return baseStyle.copyWith(
      color: scheme.tertiary,
      fontWeight: FontWeight.w600,
    );
  }
  return baseStyle.copyWith(
    color: scheme.primary,
    decoration: TextDecoration.underline,
    decorationColor: scheme.primary,
  );
}
