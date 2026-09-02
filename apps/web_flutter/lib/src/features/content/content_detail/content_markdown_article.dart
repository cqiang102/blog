part of '../content_detail_page.dart';

class _MarkdownArticle extends StatelessWidget {
  const _MarkdownArticle({required this.content, required this.headingKeys});

  final BlogContent content;
  final Map<String, GlobalKey> headingKeys;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < kSmallTabletBreakpoint;
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.md : AppSpacing.xl,
              vertical: compact ? AppSpacing.lg : AppSpacing.xl,
            ),
            child: SelectionArea(
              child: MarkdownBody(
                data: content.markdown.isEmpty
                    ? content.summary
                    : content.markdown,
                softLineBreak: true,
                styleSheet: _articleMarkdownStyle(context),
                builders: _headingBuilders(),
                imageBuilder: (uri, title, alt) =>
                    _buildMarkdownImage(context, uri, title, alt),
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrl(
                      Uri.parse(href),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// 为 h1-h6 注入稳定 key，供目录跳转定位；slug 规则与目录解析保持一致。
  Map<String, MarkdownElementBuilder> _headingBuilders() {
    final usage = <String, int>{};
    return {
      for (final level in const [1, 2, 3, 4, 5, 6])
        'h$level': _ArticleHeadingBuilder(
          level: level,
          keyForHeading: (text) {
            final slug = nextMarkdownHeadingSlug(text, usage);
            return headingKeys[slug];
          },
        ),
    };
  }

  Widget _buildMarkdownImage(
    BuildContext context,
    Uri uri,
    String? title,
    String? alt,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Semantics(
        image: true,
        label: (alt?.trim().isNotEmpty ?? false) ? alt!.trim() : '文章配图',
        excludeSemantics: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: CachedNetworkImage(
            imageUrl: resolveMediaUrl(uri.toString()),
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              constraints: const BoxConstraints(minHeight: 180),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (context, url, error) => Container(
              constraints: const BoxConstraints(minHeight: 180),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedImageNotFound01,
                    size: 40,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '图片暂时无法加载',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _articleMarkdownStyle(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final paragraph = textTheme.bodyLarge?.copyWith(
      color: scheme.onSurface,
      fontSize: 17,
      height: 1.85,
    );
    return MarkdownStyleSheet(
      p: paragraph,
      pPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      h1: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
      h2: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      h3: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      h1Padding: const EdgeInsets.only(
        top: AppSpacing.xl,
        bottom: AppSpacing.md,
      ),
      h2Padding: const EdgeInsets.only(
        top: AppSpacing.xl,
        bottom: AppSpacing.sm,
      ),
      h3Padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      listBullet: paragraph?.copyWith(color: scheme.primary),
      blockquote: paragraph?.copyWith(
        color: scheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      blockquoteDecoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      code: TextStyle(
        color: scheme.onSurface,
        backgroundColor: scheme.surfaceContainerHighest,
        fontFamily: 'monospace',
        fontSize: 14,
        height: 1.55,
      ),
      codeblockPadding: const EdgeInsets.all(AppSpacing.md),
      codeblockDecoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: scheme.outlineVariant),
      ),
      a: paragraph?.copyWith(
        color: scheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: scheme.primary,
      ),
      tableHead: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      tableBody: textTheme.bodyMedium,
      tableBorder: TableBorder.all(color: scheme.outlineVariant),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
    );
  }
}

/// 渲染带 key 的文章标题，行内加粗/斜体/代码等格式保持与默认一致。
class _ArticleHeadingBuilder extends MarkdownElementBuilder {
  _ArticleHeadingBuilder({required this.level, required this.keyForHeading});

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
      padding: _articleHeadingPadding(level),
      child: Text.rich(
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

EdgeInsets _articleHeadingPadding(int level) {
  return switch (level) {
    1 => const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
    2 => const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
    3 => const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    _ => const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
  };
}

/// 文章阅读页右侧的悬浮目录卡片。
class _ArticleTocPanel extends StatelessWidget {
  const _ArticleTocPanel({required this.headings, required this.onSelected});

  final List<MarkdownHeading> headings;
  final ValueChanged<MarkdownHeading> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm + 2,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  '目录',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${headings.length}',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              children: [
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
                        textStyle: textTheme.labelMedium,
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
          ),
        ],
      ),
    );
  }
}

/// 回到顶部的悬浮按钮，仅在向下滚动后显示。
class _BackToTopFab extends StatelessWidget {
  const _BackToTopFab({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.duration(context, AppAnimations.normal);
    return Positioned(
      right: AppSpacing.lg,
      bottom: AppSpacing.lg,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          key: const ValueKey('detail-back-to-top-fade'),
          opacity: visible ? 1 : 0,
          duration: duration,
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: visible ? 1 : 0.6,
            duration: duration,
            curve: Curves.easeOutBack,
            child: FloatingActionButton.small(
              heroTag: const ValueKey('content-detail-back-to-top'),
              tooltip: '回到顶部',
              onPressed: onPressed,
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowUp01,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 文章目录卡片宽度与出现所需的最小页面宽度。
const double _articleTocWidth = 184;
const double _articleTocMinPageWidth = 1224;

/// 向下滚动超过该距离后才显示“回到顶部”。
const double _backToTopScrollThreshold = 480;
