import 'package:flutter/material.dart';

class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final scheme = Theme.of(context).colorScheme;
    return TextSpan(
      style: baseStyle,
      children: _highlightMarkdownText(text, baseStyle, scheme),
    );
  }
}

List<TextSpan> _highlightMarkdownText(
  String text,
  TextStyle baseStyle,
  ColorScheme scheme,
) {
  if (text.isEmpty) return const [TextSpan(text: '')];

  final spans = <TextSpan>[];
  var inCodeFence = false;
  final lines = text.split('\n');

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final fenceMatch = RegExp(r'^(\s*)(```|~~~)(.*)$').firstMatch(line);

    if (fenceMatch != null) {
      spans.add(
        TextSpan(
          text: line,
          style: baseStyle.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      inCodeFence = !inCodeFence;
    } else if (inCodeFence) {
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
    r'^(\s*(?:[-*+]|\d+\.|- \[[ xX]\])\s+)(.*)$',
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
    r'(`[^`]+`)|(\*\*[^*]+\*\*)|(\*[^*]+\*)|(\[[^\]]+\]\([^)]+\))|(!?\[[^\]]*\]\([^)]+\))',
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
