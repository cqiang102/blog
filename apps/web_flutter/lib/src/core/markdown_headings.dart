// Markdown 标题解析与行内样式辅助
// 供内容编辑预览与文章详情目录共用，保证两边提取的标题/锚点一致。

import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

/// 从 Markdown 文本中提取出的一个标题。
class MarkdownHeading {
  const MarkdownHeading({
    required this.level,
    required this.text,
    required this.slug,
  });

  final int level;
  final String text;

  /// 去重后的稳定锚点，同一段文本重复出现时依次追加 -2、-3。
  final String slug;
}

/// 解析 Markdown 中的 ATX 标题（跳过代码围栏）。
List<MarkdownHeading> extractMarkdownHeadings(String data) {
  if (data.trim().isEmpty) return const [];

  final headings = <MarkdownHeading>[];
  final used = <String, int>{};
  var inCodeFence = false;

  for (final line in data.split('\n')) {
    if (RegExp(r'^\s*(```|~~~)').hasMatch(line)) {
      inCodeFence = !inCodeFence;
      continue;
    }
    if (inCodeFence) continue;

    final match = RegExp(r'^(#{1,6})\s+(.+?)\s*#*\s*$').firstMatch(line);
    if (match == null) continue;

    final text = cleanMarkdownHeadingText(match.group(2)!);
    if (text.isEmpty) continue;
    headings.add(
      MarkdownHeading(
        level: match.group(1)!.length,
        text: text,
        slug: nextMarkdownHeadingSlug(text, used),
      ),
    );
  }

  return headings;
}

/// 为标题文本生成（在整篇文档内）不重复的 slug。
String nextMarkdownHeadingSlug(String text, Map<String, int> used) {
  final base = _headingSlugBase(text);
  final count = (used[base] ?? 0) + 1;
  used[base] = count;
  return count == 1 ? base : '$base-$count';
}

/// 清洗标题展示文本：去掉图片/链接语法与行内标记符号。
String cleanMarkdownHeadingText(String text) {
  return text
      .replaceAllMapped(
        RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
        (match) => match.group(1)!,
      )
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]+\)'),
        (match) => match.group(1)!,
      )
      .replaceAll(RegExp(r'[`*_~]'), '')
      .trim();
}

String _headingSlugBase(String text) {
  final slug = cleanMarkdownHeadingText(text)
      .toLowerCase()
      .replaceAll(RegExp(r'[`*_~\[\]()]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^a-z0-9\-\u4e00-\u9fa5]'), '')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return slug.isEmpty ? 'section' : slug;
}

/// 把标题元素的行内子节点转换为带样式的 [InlineSpan]，
/// 用于在自定义标题渲染中保留 **加粗**、*斜体*、`代码` 等格式。
List<InlineSpan> markdownHeadingInlineSpans(
  BuildContext context,
  List<md.Node>? nodes,
  TextStyle parentStyle,
) {
  if (nodes == null) return const [];
  return [
    for (final node in nodes)
      if (node is md.Text)
        TextSpan(text: node.text)
      else if (node is md.Element)
        TextSpan(
          style: markdownHeadingInlineStyle(context, node.tag, parentStyle),
          children: markdownHeadingInlineSpans(
            context,
            node.children,
            parentStyle,
          ),
        ),
  ];
}

TextStyle? markdownHeadingInlineStyle(
  BuildContext context,
  String tag,
  TextStyle parentStyle,
) {
  final scheme = Theme.of(context).colorScheme;
  return switch (tag) {
    'strong' || 'b' => parentStyle.copyWith(fontWeight: FontWeight.w800),
    'em' || 'i' => parentStyle.copyWith(fontStyle: FontStyle.italic),
    'del' ||
    's' => parentStyle.copyWith(decoration: TextDecoration.lineThrough),
    'code' => parentStyle.copyWith(
      fontFamily: 'monospace',
      backgroundColor: scheme.surfaceContainerHighest,
    ),
    'a' => parentStyle.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    ),
    _ => null,
  };
}
