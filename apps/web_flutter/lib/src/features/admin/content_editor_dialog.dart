// 内容编辑器对话框
// 支持新增和编辑内容，包含标题、Slug、类型、状态、置顶、摘要、正文和标签
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_providers.dart';
import '../../core/models.dart';

/// 内容编辑器对话框
/// 支持新增和编辑内容，包含标题、Slug、类型、状态、置顶、摘要、正文和标签
class ContentEditorDialog extends ConsumerStatefulWidget {
  const ContentEditorDialog({super.key, required this.content, required this.tags});

  final AdminContentItem? content; // 待编辑内容（null 表示新增）
  final List<TagItem> tags; // 可选标签列表

  @override
  ConsumerState<ContentEditorDialog> createState() => ContentEditorDialogState();
}

/// 内容编辑器对话框状态管理
class ContentEditorDialogState extends ConsumerState<ContentEditorDialog> {
  final _formKey = GlobalKey<FormState>(); // 表单 Key
  final _titleController = TextEditingController(); // 标题输入框
  final _slugController = TextEditingController(); // Slug 输入框
  final _summaryController = TextEditingController(); // 摘要输入框
  final _bodyController = TextEditingController(); // Markdown 正文输入框
  late ContentType _type; // 内容类型
  late ContentStatus _status; // 内容状态
  late bool _pinned; // 是否置顶
  late Set<String> _tagSlugs; // 已选标签 Slug 集合
  late List<String> _mediaUrls; // 媒体 URL 列表
  bool _uploading = false; // 是否正在上传

  @override
  void initState() {
    super.initState();
    final content = widget.content;
    final draft =
        content == null
            ? const AdminContentDraft(
              title: '',
              slug: '',
              type: ContentType.article,
              status: ContentStatus.draft,
              summary: '',
              bodyMarkdown: '',
              pinned: false,
              tagSlugs: [],
            )
            : AdminContentDraft.fromItem(content);
    _titleController.text = draft.title;
    _slugController.text = draft.slug;
    _summaryController.text = draft.summary;
    _bodyController.text = draft.bodyMarkdown;
    _type = draft.type;
    _status = draft.status;
    _pinned = draft.pinned;
    _tagSlugs = draft.tagSlugs.toSet();
    _mediaUrls = content?.mediaUrls.toList() ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.content == null ? '新增内容' : '编辑内容'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '标题'),
                  maxLength: 180,
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? '请输入标题'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(labelText: 'Slug'),
                  maxLength: 220,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<ContentType>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: '类型'),
                        items: [
                          for (final type in ContentType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                        ],
                        onChanged:
                            (value) => setState(
                              () => _type = value ?? ContentType.article,
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<ContentStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: '状态'),
                        items: [
                          for (final status in ContentStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged:
                            (value) => setState(
                              () => _status = value ?? ContentStatus.draft,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('置顶'),
                  value: _pinned,
                  onChanged: (value) => setState(() => _pinned = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summaryController,
                  decoration: const InputDecoration(labelText: '摘要'),
                  maxLines: 3,
                  maxLength: 2000,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(labelText: 'Markdown 内容'),
                  minLines: 6,
                  maxLines: 12,
                ),
                if (widget.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in widget.tags)
                        FilterChip(
                          label: Text(tag.name),
                          selected: _tagSlugs.contains(tag.slug),
                          onSelected:
                              (selected) => setState(() {
                                if (selected) {
                                  _tagSlugs.add(tag.slug);
                                } else {
                                  _tagSlugs.remove(tag.slug);
                                }
                              }),
                        ),
                    ],
                  ),
                ],
                if (_type == ContentType.image || _type == ContentType.video) ...[
                  const SizedBox(height: 16),
                  _buildMediaSection(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
      ],
    );
  }

  /// 构建媒体上传区域
  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _type == ContentType.image ? '图片资源' : '视频资源',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: _uploading ? null : _pickAndUploadMedia,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_uploading ? '上传中...' : '上传文件'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_mediaUrls.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    _type == ContentType.image
                        ? Icons.image_outlined
                        : Icons.videocam_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _type == ContentType.image
                        ? '暂无图片，请上传'
                        : '暂无视频，请上传',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(_mediaUrls.length, (index) {
            final url = _mediaUrls[index];
            return Card(
              child: ListTile(
                leading: _type == ContentType.image
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          url,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image),
                        ),
                      )
                    : const Icon(Icons.videocam),
                title: Text(
                  url.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _mediaUrls.removeAt(index)),
                ),
              ),
            );
          }),
      ],
    );
  }

  /// 选择并上传媒体文件
  Future<void> _pickAndUploadMedia() async {
    try {
      final result = await FilePicker.pickFiles(
        type: _type == ContentType.image ? FileType.image : FileType.video,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _uploading = true);

      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
        return;
      }

      final mediaType = _type == ContentType.image
          ? MediaAssetType.image
          : MediaAssetType.video;

      final media = await ref.read(apiClientProvider).uploadAdminMedia(
        accessToken: token,
        bytes: file.bytes!,
        filename: file.name,
        type: mediaType,
      );

      setState(() {
        _mediaUrls.add(media.publicUrl);
        _uploading = false;
      });
    } catch (e) {
      setState(() => _uploading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败: $e')),
      );
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AdminContentDraft(
        title: _titleController.text,
        slug: _slugController.text,
        type: _type,
        status: _status,
        summary: _summaryController.text,
        bodyMarkdown: _bodyController.text,
        pinned: _pinned,
        tagSlugs: _tagSlugs.toList()..sort(),
        mediaUrls: _mediaUrls,
      ),
    );
  }
}
