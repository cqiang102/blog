import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:highlight/highlight_core.dart' as highlight;
import 'package:highlight/languages/bash.dart' as highlight_bash;
import 'package:highlight/languages/cpp.dart' as highlight_cpp;
import 'package:highlight/languages/css.dart' as highlight_css;
import 'package:highlight/languages/dart.dart' as highlight_dart;
import 'package:highlight/languages/diff.dart' as highlight_diff;
import 'package:highlight/languages/dockerfile.dart' as highlight_dockerfile;
import 'package:highlight/languages/go.dart' as highlight_go;
import 'package:highlight/languages/gradle.dart' as highlight_gradle;
import 'package:highlight/languages/groovy.dart' as highlight_groovy;
import 'package:highlight/languages/ini.dart' as highlight_ini;
import 'package:highlight/languages/java.dart' as highlight_java;
import 'package:highlight/languages/javascript.dart' as highlight_javascript;
import 'package:highlight/languages/json.dart' as highlight_json;
import 'package:highlight/languages/kotlin.dart' as highlight_kotlin;
import 'package:highlight/languages/markdown.dart' as highlight_markdown;
import 'package:highlight/languages/nginx.dart' as highlight_nginx;
import 'package:highlight/languages/php.dart' as highlight_php;
import 'package:highlight/languages/properties.dart' as highlight_properties;
import 'package:highlight/languages/python.dart' as highlight_python;
import 'package:highlight/languages/ruby.dart' as highlight_ruby;
import 'package:highlight/languages/rust.dart' as highlight_rust;
import 'package:highlight/languages/shell.dart' as highlight_shell;
import 'package:highlight/languages/sql.dart' as highlight_sql;
import 'package:highlight/languages/swift.dart' as highlight_swift;
import 'package:highlight/languages/typescript.dart' as highlight_typescript;
import 'package:highlight/languages/xml.dart' as highlight_xml;
import 'package:highlight/languages/yaml.dart' as highlight_yaml;
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants.dart';
import '../../../../core/media_url.dart';
import '../../../../theme/app_spacing.dart';
import '../markdown_edit_command.dart';
import '../content_editor_state.dart';
import 'markdown_toolbar.dart';

part 'markdown_preview_support.dart';

class EditorMainPanel extends StatelessWidget {
  const EditorMainPanel({
    super.key,
    required this.state,
    required this.titleController,
    required this.summaryController,
    required this.bodyController,
    required this.bodyFocusNode,
    required this.onTitleChanged,
    required this.onSummaryChanged,
    required this.onBodyChanged,
    required this.onMarkdownAction,
    required this.onInsertCodeBlockLanguage,
    required this.onInsertImage,
    required this.onOpenTableEditor,
    required this.onEditModeChanged,
    required this.mediaChild,
  });

  final ContentEditorState state;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController bodyController;
  final FocusNode bodyFocusNode;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onSummaryChanged;
  final ValueChanged<String> onBodyChanged;
  final ValueChanged<MarkdownEditAction> onMarkdownAction;
  final ValueChanged<String> onInsertCodeBlockLanguage;
  final VoidCallback onInsertImage;
  final VoidCallback onOpenTableEditor;
  final ValueChanged<EditorEditMode> onEditModeChanged;
  final Widget mediaChild;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const ValueKey('content-editor-title-field'),
          controller: titleController,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: 18, height: 1.3),
          decoration: _editorMetadataDecoration(context, hintText: '标题'),
          maxLength: 180,
          buildCounter: _hideEditorLengthCounter,
          textInputAction: TextInputAction.next,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) =>
              value == null || value.trim().isEmpty ? '请输入标题' : null,
          onChanged: onTitleChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          key: const ValueKey('content-editor-summary-field'),
          controller: summaryController,
          decoration: _editorMetadataDecoration(context, hintText: '摘要（可选）'),
          minLines: 1,
          maxLines: 3,
          maxLength: 2000,
          buildCounter: _hideEditorLengthCounter,
          onChanged: onSummaryChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.isMediaType)
          mediaChild
        else
          _MarkdownPanel(
            state: state,
            bodyController: bodyController,
            bodyFocusNode: bodyFocusNode,
            onBodyChanged: onBodyChanged,
            onMarkdownAction: onMarkdownAction,
            onInsertCodeBlockLanguage: onInsertCodeBlockLanguage,
            onInsertImage: onInsertImage,
            onOpenTableEditor: onOpenTableEditor,
            onEditModeChanged: onEditModeChanged,
          ),
      ],
    );
  }
}

InputDecoration _editorMetadataDecoration(
  BuildContext context, {
  required String hintText,
}) {
  final scheme = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(12);
  final enabledBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return InputDecoration(
    hintText: hintText,
    counterText: '',
    isDense: true,
    filled: true,
    fillColor: scheme.surfaceContainerLowest,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 12,
    ),
    border: enabledBorder,
    enabledBorder: enabledBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    ),
  );
}

Widget? _hideEditorLengthCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

class _MarkdownPanel extends StatefulWidget {
  const _MarkdownPanel({
    required this.state,
    required this.bodyController,
    required this.bodyFocusNode,
    required this.onBodyChanged,
    required this.onMarkdownAction,
    required this.onInsertCodeBlockLanguage,
    required this.onInsertImage,
    required this.onOpenTableEditor,
    required this.onEditModeChanged,
  });

  final ContentEditorState state;
  final TextEditingController bodyController;
  final FocusNode bodyFocusNode;
  final ValueChanged<String> onBodyChanged;
  final ValueChanged<MarkdownEditAction> onMarkdownAction;
  final ValueChanged<String> onInsertCodeBlockLanguage;
  final VoidCallback onInsertImage;
  final VoidCallback onOpenTableEditor;
  final ValueChanged<EditorEditMode> onEditModeChanged;

  @override
  State<_MarkdownPanel> createState() => _MarkdownPanelState();
}

class _MarkdownPanelState extends State<_MarkdownPanel> {
  final _sourceScrollController = ScrollController();
  final _previewScrollController = ScrollController();
  bool _isSyncingScroll = false;

  @override
  void initState() {
    super.initState();
    _sourceScrollController.addListener(_handleSourceScroll);
    _previewScrollController.addListener(_handlePreviewScroll);
  }

  @override
  void didUpdateWidget(covariant _MarkdownPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.editMode != widget.state.editMode ||
        oldWidget.state.bodyMarkdown != widget.state.bodyMarkdown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _clampScrollOffset(_sourceScrollController);
        _clampScrollOffset(_previewScrollController);
        if (widget.state.editMode == EditorEditMode.split) {
          _handleSourceScroll();
        }
      });
    }
  }

  @override
  void dispose() {
    _sourceScrollController.removeListener(_handleSourceScroll);
    _previewScrollController.removeListener(_handlePreviewScroll);
    _sourceScrollController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  void _handleSourceScroll() {
    if (!_sourceScrollController.hasClients) return;
    _syncScrollMetrics(
      sourceMetrics: _sourceScrollController.position,
      target: _previewScrollController,
    );
  }

  void _handlePreviewScroll() {
    if (!_previewScrollController.hasClients) return;
    _syncScrollMetrics(
      sourceMetrics: _previewScrollController.position,
      target: _sourceScrollController,
    );
  }

  void _syncScrollMetrics({
    required ScrollMetrics sourceMetrics,
    required ScrollController target,
  }) {
    if (widget.state.editMode != EditorEditMode.split ||
        _isSyncingScroll ||
        !target.hasClients) {
      return;
    }

    final targetPosition = target.position;
    if (!targetPosition.hasContentDimensions) {
      return;
    }

    final sourceMax = sourceMetrics.maxScrollExtent;
    final targetMax = targetPosition.maxScrollExtent;
    final ratio = sourceMax <= 0
        ? 0.0
        : (sourceMetrics.pixels / sourceMax).clamp(0.0, 1.0).toDouble();
    final nextOffset = targetMax <= 0 ? 0.0 : targetMax * ratio;
    final clampedOffset = nextOffset
        .clamp(targetPosition.minScrollExtent, targetPosition.maxScrollExtent)
        .toDouble();

    if ((targetPosition.pixels - clampedOffset).abs() < 0.5) return;

    _isSyncingScroll = true;
    try {
      target.jumpTo(clampedOffset);
    } finally {
      _isSyncingScroll = false;
    }
  }

  void _clampScrollOffset(ScrollController controller) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    final clampedOffset = position.pixels
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - clampedOffset).abs() < 0.5) return;
    controller.jumpTo(clampedOffset);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.width < kTabletBreakpoint;
    final panelHeight = (viewport.height * 0.56)
        .clamp(compact ? 420.0 : 480.0, compact ? 600.0 : 660.0)
        .toDouble();
    final characterCount = widget.state.bodyMarkdown.trim().runes.length;
    return RepaintBoundary(
      key: const ValueKey('content-editor-markdown-panel'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 520),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.08),
              blurRadius: 0,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: MarkdownToolbar(
                        onAction: widget.onMarkdownAction,
                        editMode: widget.state.editMode,
                        onSetEditMode: widget.onEditModeChanged,
                        onInsertImage: widget.onInsertImage,
                        onInsertCodeBlockLanguage:
                            widget.onInsertCodeBlockLanguage,
                        onOpenTableEditor: widget.onOpenTableEditor,
                      ),
                    ),
                    if (constraints.maxWidth >= kTabletBreakpoint) ...[
                      const SizedBox(width: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.only(top: 11, right: 6),
                        child: _CharacterCount(value: characterCount),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            SizedBox(
              height: panelHeight,
              child: switch (widget.state.editMode) {
                EditorEditMode.source => _buildSourcePane(scheme),
                EditorEditMode.split => LayoutBuilder(
                  builder: (context, constraints) {
                    final source = _buildSourcePane(scheme);
                    final preview = _buildPreviewPane(scheme);
                    if (constraints.maxWidth >= kTabletBreakpoint) {
                      return Row(
                        children: [
                          Expanded(flex: 11, child: source),
                          VerticalDivider(
                            width: 1,
                            color: scheme.outlineVariant,
                          ),
                          Expanded(flex: 9, child: preview),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(flex: 11, child: source),
                        Divider(height: 1, color: scheme.outlineVariant),
                        Expanded(flex: 9, child: preview),
                      ],
                    );
                  },
                ),
                EditorEditMode.preview => _buildPreviewPane(scheme),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcePane(ColorScheme scheme) {
    return ColoredBox(
      key: const ValueKey('content-editor-source-pane'),
      color: scheme.surfaceContainerLow.withValues(alpha: 0.46),
      child: _SourceEditor(
        controller: widget.bodyController,
        focusNode: widget.bodyFocusNode,
        scrollController: _sourceScrollController,
        onScrollMetrics: (metrics) => _syncScrollMetrics(
          sourceMetrics: metrics,
          target: _previewScrollController,
        ),
        onChanged: widget.onBodyChanged,
      ),
    );
  }

  Widget _buildPreviewPane(ColorScheme scheme) {
    return ColoredBox(
      key: const ValueKey('content-editor-preview-pane'),
      color: scheme.surface,
      child: _MarkdownPreview(
        data: widget.state.bodyMarkdown,
        scrollController: _previewScrollController,
        onScrollMetrics: (metrics) => _syncScrollMetrics(
          sourceMetrics: metrics,
          target: _sourceScrollController,
        ),
      ),
    );
  }
}

class _CharacterCount extends StatelessWidget {
  const _CharacterCount({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$value 字',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _SourceEditor extends StatelessWidget {
  const _SourceEditor({
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.onScrollMetrics,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final ValueChanged<ScrollMetrics> onScrollMetrics;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) {
          onScrollMetrics(notification.metrics);
        }
        return false;
      },
      child: Scrollbar(
        controller: scrollController,
        child: TextFormField(
          key: const ValueKey('content-editor-source-field'),
          controller: controller,
          focusNode: focusNode,
          scrollController: scrollController,
          expands: true,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            height: 1.55,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            hintText: '开始撰写 Markdown 内容…',
            contentPadding: EdgeInsets.all(AppSpacing.lg),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final headings = _extractMarkdownHeadings(widget.data);
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
                      data: widget.data.trim().isEmpty ? '*暂无内容*' : widget.data,
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
                          placeholder: (_, __) => const Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Center(
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Padding(
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
