part of '../content_detail_page.dart';

class _MarkdownArticle extends StatelessWidget {
  const _MarkdownArticle({required this.content});

  final BlogContent content;

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
