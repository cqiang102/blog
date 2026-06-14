import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../../core/media_url.dart';
import '../../../../theme/app_spacing.dart';
import '../content_editor_state.dart';
import 'markdown_toolbar.dart';

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
    required this.onInsertImage,
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
  final VoidCallback onInsertImage;
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
            onInsertImage: onInsertImage,
            onEditModeChanged: onEditModeChanged,
          ),
      ],
    );
  }
}

class _MarkdownPanel extends StatelessWidget {
  const _MarkdownPanel({
    required this.state,
    required this.bodyController,
    required this.bodyFocusNode,
    required this.onBodyChanged,
    required this.onInsertMarkdown,
    required this.onInsertImage,
    required this.onEditModeChanged,
  });

  final ContentEditorState state;
  final TextEditingController bodyController;
  final FocusNode bodyFocusNode;
  final ValueChanged<String> onBodyChanged;
  final void Function(String prefix, String suffix) onInsertMarkdown;
  final VoidCallback onInsertImage;
  final ValueChanged<EditorEditMode> onEditModeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: MarkdownToolbar(
              onInsert: onInsertMarkdown,
              editMode: state.editMode,
              onSetEditMode: onEditModeChanged,
              onInsertImage: onInsertImage,
              mediaUrls: state.mediaUrls,
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          SizedBox(
            height: 520,
            child: switch (state.editMode) {
              EditorEditMode.source => _SourceEditor(
                controller: bodyController,
                focusNode: bodyFocusNode,
                onChanged: onBodyChanged,
              ),
              EditorEditMode.split => Row(
                children: [
                  Expanded(
                    child: _SourceEditor(
                      controller: bodyController,
                      focusNode: bodyFocusNode,
                      onChanged: onBodyChanged,
                    ),
                  ),
                  VerticalDivider(width: 1, color: scheme.outlineVariant),
                  Expanded(child: _MarkdownPreview(data: state.bodyMarkdown)),
                ],
              ),
              EditorEditMode.preview => _MarkdownPreview(
                data: state.bodyMarkdown,
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
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      expands: true,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: '开始撰写 Markdown 内容…',
        contentPadding: EdgeInsets.all(AppSpacing.md),
      ),
      onChanged: onChanged,
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: MarkdownBody(
        data: data.trim().isEmpty ? '*暂无内容*' : data,
        selectable: true,
        imageBuilder: (uri, title, alt) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: resolveMediaUrl(uri.toString()),
            fit: BoxFit.contain,
            placeholder: (_, __) => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
            errorWidget: (_, __, ___) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(alt ?? '图片加载失败'),
            ),
          ),
        ),
      ),
    );
  }
}
