part of 'editor_main_panel.dart';

class _MarkdownPreview extends StatefulWidget {
  const _MarkdownPreview({
    required this.data,
    required this.scrollController,
    required this.onScrollMetrics,
  });

  final String data;
  final ScrollController scrollController;
  final ValueChanged<ScrollMetrics> onScrollMetrics;

  @override
  State<_MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<_MarkdownPreview> {
  final _headingKeys = <String, GlobalKey>{};
  Timer? _debounceTimer;
  late String _debouncedData;

  @override
  void initState() {
    super.initState();
    _debouncedData = widget.data;
  }

  @override
  void didUpdateWidget(covariant _MarkdownPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _debouncedData = widget.data);
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headings = _extractMarkdownHeadings(_debouncedData);
    final currentSlugs = headings.map((heading) => heading.slug).toSet();
    _headingKeys.removeWhere((slug, _) => !currentSlugs.contains(slug));
    for (final heading in headings) {
      _headingKeys.putIfAbsent(heading.slug, GlobalKey.new);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showToc = headings.length > 1 && constraints.maxWidth >= 680;
        if (showToc) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 184,
                child: _MarkdownToc(
                  headings: headings,
                  onSelected: _scrollToHeading,
                ),
              ),
              VerticalDivider(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, previewConstraints) =>
                      _buildScrollablePreview(
                        context,
                        previewConstraints,
                        headings,
                      ),
                ),
              ),
            ],
          );
        }

        return _buildScrollablePreview(context, constraints, headings);
      },
    );
  }

  Widget _buildScrollablePreview(
    BuildContext context,
    BoxConstraints constraints,
    List<_MarkdownHeading> headings,
  ) {
    final headingUsage = <String, int>{};
    final builders = <String, MarkdownElementBuilder>{
      'pre': _MarkdownCodeBlockBuilder(),
      for (final level in [1, 2, 3, 4, 5, 6])
        'h$level': _MarkdownHeadingBuilder(
          level: level,
          keyForHeading: (text) {
            final slug = _nextHeadingSlug(text, headingUsage);
            return _headingKeys[slug];
          },
        ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math.max(
          0.0,
          constraints.maxWidth - AppSpacing.lg * 2,
        );
        final contentHeight = math.max(
          0.0,
          constraints.maxHeight - AppSpacing.lg * 2,
        );
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical) {
              widget.onScrollMetrics(notification.metrics);
            }
            return false;
          },
          child: Scrollbar(
            controller: widget.scrollController,
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: contentWidth,
                  minHeight: contentHeight,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: contentWidth,
                    child: MarkdownBody(
                      key: const ValueKey('content-editor-markdown-preview'),
                      data: _debouncedData.trim().isEmpty ? '*暂无内容*' : _debouncedData,
                      selectable: true,
                      fitContent: false,
                      softLineBreak: true,
                      styleSheet: _editorPreviewMarkdownStyle(context),
                      builders: builders,
                      onTapLink: (_, href, _) => _openLink(context, href),
                      imageBuilder: (uri, title, alt) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: resolveMediaUrl(uri.toString()),
                          fit: BoxFit.contain,
                          placeholder: (_, _) => const Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Center(
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          ),
                          errorWidget: (_, _, _) => Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(alt ?? '图片加载失败'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _scrollToHeading(_MarkdownHeading heading) {
    final headingContext = _headingKeys[heading.slug]?.currentContext;
    if (headingContext == null) return;
    Scrollable.ensureVisible(
      headingContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  void _openLink(BuildContext context, String? href) {
    if (href == null || href.trim().isEmpty) return;
    unawaited(_launchPreviewLink(context, href));
  }

  Future<void> _launchPreviewLink(BuildContext context, String href) async {
    final parsed = Uri.tryParse(href);
    if (parsed == null) return;
    final uri = parsed.hasScheme ? parsed : Uri.base.resolveUri(parsed);
    if (!const {'http', 'https', 'mailto'}.contains(uri.scheme)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该链接类型无法预览')));
      }
      return;
    }

    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }
}
