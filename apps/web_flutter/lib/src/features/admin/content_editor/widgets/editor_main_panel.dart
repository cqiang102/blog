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

import '../../../../core/constants.dart';
import '../../../../core/media_url.dart';
import '../../../../theme/app_spacing.dart';
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
    required this.onInsertMarkdown,
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
  final void Function(String prefix, String suffix) onInsertMarkdown;
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
          controller: titleController,
          style: Theme.of(context).textTheme.headlineSmall,
          decoration: const InputDecoration(
            hintText: '输入一个清晰的内容标题',
            labelText: '标题',
          ),
          maxLength: 180,
          textInputAction: TextInputAction.next,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) =>
              value == null || value.trim().isEmpty ? '请输入标题' : null,
          onChanged: onTitleChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: summaryController,
          decoration: const InputDecoration(
            labelText: '摘要',
            hintText: '用于列表、搜索结果和分享卡片的简短介绍',
            alignLabelWithHint: true,
          ),
          minLines: 2,
          maxLines: 4,
          maxLength: 2000,
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
            onInsertMarkdown: onInsertMarkdown,
            onInsertCodeBlockLanguage: onInsertCodeBlockLanguage,
            onInsertImage: onInsertImage,
            onOpenTableEditor: onOpenTableEditor,
            onEditModeChanged: onEditModeChanged,
          ),
      ],
    );
  }
}

class _MarkdownPanel extends StatefulWidget {
  const _MarkdownPanel({
    required this.state,
    required this.bodyController,
    required this.bodyFocusNode,
    required this.onBodyChanged,
    required this.onInsertMarkdown,
    required this.onInsertCodeBlockLanguage,
    required this.onInsertImage,
    required this.onOpenTableEditor,
    required this.onEditModeChanged,
  });

  final ContentEditorState state;
  final TextEditingController bodyController;
  final FocusNode bodyFocusNode;
  final ValueChanged<String> onBodyChanged;
  final void Function(String prefix, String suffix) onInsertMarkdown;
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
    final panelHeight = (MediaQuery.sizeOf(context).height - 240)
        .clamp(520.0, 860.0)
        .toDouble();
    final characterCount = widget.state.bodyMarkdown.trim().runes.length;
    return Container(
      constraints: const BoxConstraints(minHeight: 520),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MarkdownToolbar(
                      onInsert: widget.onInsertMarkdown,
                      editMode: widget.state.editMode,
                      onSetEditMode: widget.onEditModeChanged,
                      onInsertImage: widget.onInsertImage,
                      onInsertCodeBlockLanguage:
                          widget.onInsertCodeBlockLanguage,
                      onOpenTableEditor: widget.onOpenTableEditor,
                      mediaUrls: widget.state.mediaUrls,
                    ),
                  ),
                  if (constraints.maxWidth >= kTabletBreakpoint) ...[
                    const SizedBox(width: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 6),
                      child: Text(
                        '$characterCount 字',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
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
              EditorEditMode.source => _SourceEditor(
                controller: widget.bodyController,
                focusNode: widget.bodyFocusNode,
                scrollController: _sourceScrollController,
                onScrollMetrics: (metrics) => _syncScrollMetrics(
                  sourceMetrics: metrics,
                  target: _previewScrollController,
                ),
                onChanged: widget.onBodyChanged,
              ),
              EditorEditMode.split => Row(
                children: [
                  Expanded(
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
                  ),
                  VerticalDivider(width: 1, color: scheme.outlineVariant),
                  Expanded(
                    child: _MarkdownPreview(
                      data: widget.state.bodyMarkdown,
                      scrollController: _previewScrollController,
                      onScrollMetrics: (metrics) => _syncScrollMetrics(
                        sourceMetrics: metrics,
                        target: _sourceScrollController,
                      ),
                    ),
                  ),
                ],
              ),
              EditorEditMode.preview => _MarkdownPreview(
                data: widget.state.bodyMarkdown,
                scrollController: _previewScrollController,
                onScrollMetrics: (_) {},
              ),
            },
          ),
        ],
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
          controller: controller,
          focusNode: focusNode,
          scrollController: scrollController,
          expands: true,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            height: 1.45,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: '开始撰写 Markdown 内容…',
            contentPadding: EdgeInsets.all(AppSpacing.md),
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
      for (final level in [1, 2, 3])
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
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: contentWidth),
                  child: MarkdownBody(
                    data: widget.data.trim().isEmpty ? '*暂无内容*' : widget.data,
                    selectable: true,
                    fitContent: false,
                    softLineBreak: true,
                    styleSheet: _editorPreviewMarkdownStyle(context),
                    builders: builders,
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
}
