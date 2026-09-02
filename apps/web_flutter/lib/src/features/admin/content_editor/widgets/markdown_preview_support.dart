part of 'editor_main_panel.dart';

class _MarkdownToc extends StatelessWidget {
  const _MarkdownToc({required this.headings, required this.onSelected});

  final List<MarkdownHeading> headings;
  final ValueChanged<MarkdownHeading> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainerLow),
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              '目录',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final heading in headings)
            Padding(
              padding: EdgeInsets.only(left: (heading.level - 1) * 10.0),
              child: TextButton(
                onPressed: () => onSelected(heading),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: scheme.onSurface,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                child: Text(
                  heading.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarkdownHeadingBuilder extends MarkdownElementBuilder {
  _MarkdownHeadingBuilder({required this.level, required this.keyForHeading});

  final int level;
  final GlobalKey? Function(String text) keyForHeading;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final style =
        preferredStyle ??
        Theme.of(context).textTheme.titleMedium ??
        const TextStyle();
    final headingStyle = style.copyWith(fontWeight: FontWeight.w700);
    return Padding(
      key: keyForHeading(element.textContent),
      padding: EdgeInsets.only(
        top: level == 1 ? AppSpacing.sm : AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: SelectableText.rich(
        TextSpan(
          style: headingStyle,
          children: markdownHeadingInlineSpans(
            context,
            element.children,
            headingStyle,
          ),
        ),
      ),
    );
  }
}

class _MarkdownCodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final codeElement = _findCodeElement(element);
    final code = (codeElement ?? element).textContent.replaceFirst(
      RegExp(r'\n$'),
      '',
    );
    final language = _languageFromCodeClass(codeElement?.attributes['class']);

    return _HighlightedCodeBlock(code: code, language: language);
  }

  md.Element? _findCodeElement(md.Element element) {
    final children = element.children;
    if (children == null) return null;

    for (final child in children) {
      if (child is md.Element && child.tag == 'code') {
        return child;
      }
    }
    return null;
  }
}

class _HighlightedCodeBlock extends StatefulWidget {
  const _HighlightedCodeBlock({required this.code, required this.language});

  final String code;
  final String? language;

  @override
  State<_HighlightedCodeBlock> createState() => _HighlightedCodeBlockState();
}

class _HighlightedCodeBlockState extends State<_HighlightedCodeBlock> {
  final _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final codeStyle = _editorCodeTextStyle(context);
    final palette = _EditorSyntaxPalette(scheme);
    final languageLabel = _displayCodeLanguage(widget.language);

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: _editorCodeBlockDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.xs,
                top: AppSpacing.xs,
                bottom: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Text(
                    languageLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '复制代码',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copyCode(context),
                    icon: const Icon(Icons.content_copy_rounded, size: 16),
                  ),
                ],
              ),
            ),
          ),
          Scrollbar(
            controller: _horizontalScrollController,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              padding: _editorCodeBlockPadding,
              child: SelectableText.rich(
                _highlightedCodeSpan(
                  code: widget.code,
                  language: widget.language,
                  baseStyle: codeStyle,
                  palette: palette,
                ),
                textWidthBasis: TextWidthBasis.longestLine,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('代码已复制')));
  }
}

class _EditorSyntaxPalette {
  _EditorSyntaxPalette(ColorScheme scheme)
    : keyword = scheme.brightness == Brightness.dark
          ? const Color(0xFFC4B5FD)
          : const Color(0xFF6D28D9),
      type = scheme.brightness == Brightness.dark
          ? const Color(0xFF93C5FD)
          : const Color(0xFF1D4ED8),
      string = scheme.brightness == Brightness.dark
          ? const Color(0xFF5EEAD4)
          : const Color(0xFF0F766E),
      literal = scheme.brightness == Brightness.dark
          ? const Color(0xFFFBBF24)
          : const Color(0xFFB45309),
      comment = scheme.onSurfaceVariant.withValues(alpha: 0.78),
      meta = scheme.brightness == Brightness.dark
          ? const Color(0xFFFCA5A5)
          : const Color(0xFFB91C1C),
      variable = scheme.brightness == Brightness.dark
          ? const Color(0xFFF0ABFC)
          : const Color(0xFFA21CAF),
      addition = scheme.brightness == Brightness.dark
          ? const Color(0xFF86EFAC)
          : const Color(0xFF15803D),
      deletion = scheme.brightness == Brightness.dark
          ? const Color(0xFFFCA5A5)
          : const Color(0xFFB91C1C);

  final Color keyword;
  final Color type;
  final Color string;
  final Color literal;
  final Color comment;
  final Color meta;
  final Color variable;
  final Color addition;
  final Color deletion;

  TextStyle styleFor(String className) {
    final token = className.toLowerCase();

    if (token.contains('comment') || token == 'quote') {
      return TextStyle(color: comment, fontStyle: FontStyle.italic);
    }
    if (token.contains('string') || token == 'regexp') {
      return TextStyle(color: string);
    }
    if (token == 'keyword' || token == 'built_in' || token == 'selector-tag') {
      return TextStyle(color: keyword, fontWeight: FontWeight.w600);
    }
    if (token == 'type' ||
        token == 'class' ||
        token == 'title' ||
        token == 'function' ||
        token == 'name' ||
        token == 'tag') {
      return TextStyle(color: type, fontWeight: FontWeight.w600);
    }
    if (token == 'number' ||
        token == 'literal' ||
        token == 'symbol' ||
        token == 'bullet') {
      return TextStyle(color: literal);
    }
    if (token.contains('meta') ||
        token == 'doctag' ||
        token == 'section' ||
        token == 'selector-id') {
      return TextStyle(color: meta, fontWeight: FontWeight.w600);
    }
    if (token == 'attr' ||
        token == 'attribute' ||
        token == 'variable' ||
        token == 'template-variable' ||
        token == 'selector-class') {
      return TextStyle(color: variable);
    }
    if (token == 'addition') {
      return TextStyle(color: addition);
    }
    if (token == 'deletion') {
      return TextStyle(color: deletion);
    }

    return const TextStyle();
  }
}

MarkdownStyleSheet _editorPreviewMarkdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final textTheme = theme.textTheme;
  final bodyStyle = textTheme.bodyMedium ?? const TextStyle();
  final codeStyle = _editorCodeTextStyle(context);

  return MarkdownStyleSheet(
    p: bodyStyle.copyWith(color: scheme.onSurface, height: 1.55),
    h1: textTheme.headlineSmall?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
    ),
    h2: textTheme.titleLarge?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
    ),
    h3: textTheme.titleMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
    ),
    code: codeStyle.copyWith(
      color: scheme.onSurface,
      backgroundColor: scheme.surfaceContainerHighest,
    ),
    codeblockPadding: _editorCodeBlockPadding,
    codeblockDecoration: _editorCodeBlockDecoration(scheme),
    blockquote: bodyStyle.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
    blockquotePadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    blockquoteDecoration: BoxDecoration(
      color: scheme.surfaceContainer,
      border: Border(left: BorderSide(color: scheme.primary, width: 3)),
    ),
    tableHead: textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
    ),
    tableBody: bodyStyle.copyWith(color: scheme.onSurface),
    tableBorder: TableBorder.all(color: scheme.outlineVariant),
  );
}

const _editorCodeBlockPadding = EdgeInsets.all(AppSpacing.md);

final highlight.Highlight _editorCodeHighlighter = highlight.Highlight()
  ..registerLanguage('bash', highlight_bash.bash)
  ..registerLanguage('shell', highlight_shell.shell)
  ..registerLanguage('dart', highlight_dart.dart)
  ..registerLanguage('java', highlight_java.java)
  ..registerLanguage('kotlin', highlight_kotlin.kotlin)
  ..registerLanguage('gradle', highlight_gradle.gradle)
  ..registerLanguage('groovy', highlight_groovy.groovy)
  ..registerLanguage('dockerfile', highlight_dockerfile.dockerfile)
  ..registerLanguage('json', highlight_json.json)
  ..registerLanguage('yaml', highlight_yaml.yaml)
  ..registerLanguage('xml', highlight_xml.xml)
  ..registerLanguage('css', highlight_css.css)
  ..registerLanguage('javascript', highlight_javascript.javascript)
  ..registerLanguage('typescript', highlight_typescript.typescript)
  ..registerLanguage('markdown', highlight_markdown.markdown)
  ..registerLanguage('sql', highlight_sql.sql)
  ..registerLanguage('python', highlight_python.python)
  ..registerLanguage('go', highlight_go.go)
  ..registerLanguage('rust', highlight_rust.rust)
  ..registerLanguage('swift', highlight_swift.swift)
  ..registerLanguage('php', highlight_php.php)
  ..registerLanguage('ruby', highlight_ruby.ruby)
  ..registerLanguage('cpp', highlight_cpp.cpp)
  ..registerLanguage('diff', highlight_diff.diff)
  ..registerLanguage('ini', highlight_ini.ini)
  ..registerLanguage('properties', highlight_properties.properties)
  ..registerLanguage('nginx', highlight_nginx.nginx);

BoxDecoration _editorCodeBlockDecoration(ColorScheme scheme) {
  return BoxDecoration(
    color: scheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: scheme.outlineVariant),
  );
}

TextStyle _editorCodeTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  final bodyStyle = theme.textTheme.bodyMedium ?? const TextStyle();

  return bodyStyle.copyWith(
    color: theme.colorScheme.onSurface,
    fontFamily: 'monospace',
    fontSize: (bodyStyle.fontSize ?? 14) * 0.9,
    height: 1.45,
  );
}

TextSpan _highlightedCodeSpan({
  required String code,
  required String? language,
  required TextStyle baseStyle,
  required _EditorSyntaxPalette palette,
}) {
  final normalizedLanguage = _normalizeCodeLanguage(language);
  if (normalizedLanguage == null) {
    return TextSpan(style: baseStyle, text: code);
  }

  final highlight.Result result;
  try {
    result = _editorCodeHighlighter.parse(code, language: normalizedLanguage);
  } on ArgumentError {
    // Language not registered with the highlighter; fall back to plain text.
    return TextSpan(style: baseStyle, text: code);
  }
  final children = <TextSpan>[];
  for (final node in result.nodes ?? const <highlight.Node>[]) {
    _appendHighlightNode(children, node, baseStyle, palette);
  }

  if (children.isEmpty) {
    return TextSpan(style: baseStyle, text: code);
  }

  return TextSpan(style: baseStyle, children: children);
}

void _appendHighlightNode(
  List<TextSpan> spans,
  highlight.Node node,
  TextStyle inheritedStyle,
  _EditorSyntaxPalette palette,
) {
  final nodeStyle = node.className == null
      ? inheritedStyle
      : inheritedStyle.merge(palette.styleFor(node.className!));

  final value = node.value;
  if (value != null) {
    spans.add(TextSpan(text: value, style: nodeStyle));
    return;
  }

  final children = node.children;
  if (children == null) return;

  for (final child in children) {
    _appendHighlightNode(spans, child, nodeStyle, palette);
  }
}

String? _languageFromCodeClass(String? className) {
  if (className == null || className.trim().isEmpty) return null;

  final parts = className.trim().split(RegExp(r'\s+'));
  for (final part in parts) {
    if (part.startsWith('language-')) {
      return part.substring('language-'.length);
    }
  }

  return parts.first;
}

String _displayCodeLanguage(String? language) {
  final normalized = _normalizeCodeLanguage(language);
  if (normalized == null) return 'text';

  return switch (normalized) {
    'bash' => 'bash',
    'dockerfile' => 'dockerfile',
    'javascript' => 'javascript',
    'typescript' => 'typescript',
    _ => normalized,
  };
}

String? _normalizeCodeLanguage(String? language) {
  final normalized = language?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;

  return switch (normalized) {
    'console' || 'terminal' => 'shell',
    'docker' => 'dockerfile',
    'gradle.kts' => 'kotlin',
    'js' || 'jsx' => 'javascript',
    'kt' || 'kts' => 'kotlin',
    'md' => 'markdown',
    'plist' => 'xml',
    'props' => 'properties',
    'py' => 'python',
    'rs' => 'rust',
    'sh' || 'zsh' => 'bash',
    'ts' || 'tsx' => 'typescript',
    'yml' => 'yaml',
    _ => normalized,
  };
}
