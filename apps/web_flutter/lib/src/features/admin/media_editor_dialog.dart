// 媒体编辑器对话框
// 支持编辑媒体资源的标题、描述和关联内容
import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import 'admin_widgets.dart';

/// 媒体编辑器对话框
/// 支持新增和编辑媒体资源，包含 URL、文件名、MIME 类型和尺寸信息
class MediaEditorDialog extends StatefulWidget {
  const MediaEditorDialog({
    super.key,
    required this.media,
    required this.contents,
  });

  final AdminMediaItem? media; // 待编辑媒体（null 表示新增）
  final List<AdminContentItem> contents; // 可绑定的内容列表

  @override
  State<MediaEditorDialog> createState() => MediaEditorDialogState();
}

/// 媒体编辑器对话框状态管理
class MediaEditorDialogState extends State<MediaEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _filenameController = TextEditingController();
  final _contentTypeController = TextEditingController();
  final _byteSizeController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _durationController = TextEditingController();
  late MediaAssetType _type;
  late String _contentId;

  @override
  void initState() {
    super.initState();
    final media = widget.media;
    final draft =
        media == null
            ? const AdminMediaDraft(
              contentId: '',
              type: MediaAssetType.image,
              publicUrl: '',
              filename: '',
              contentType: 'image/jpeg',
              byteSize: null,
              width: null,
              height: null,
              durationSeconds: null,
            )
            : AdminMediaDraft.fromItem(media);
    final knownContent = widget.contents.any(
      (content) => content.id == draft.contentId,
    );
    _contentId = knownContent ? draft.contentId : '';
    _type = draft.type;
    _urlController.text = draft.publicUrl;
    _filenameController.text = draft.filename;
    _contentTypeController.text = draft.contentType;
    _byteSizeController.text = draft.byteSize?.toString() ?? '';
    _widthController.text = draft.width?.toString() ?? '';
    _heightController.text = draft.height?.toString() ?? '';
    _durationController.text = draft.durationSeconds?.toString() ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    _filenameController.dispose();
    _contentTypeController.dispose();
    _byteSizeController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminEditorDialog(
      title: widget.media == null ? '新增媒体' : '编辑媒体',
      subtitle: '维护资源地址、文件信息和关联内容',
      maxWidth: 860,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存媒体')),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminFormSection(
              title: '资源信息',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _contentId,
                    decoration: const InputDecoration(labelText: '绑定内容'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('不绑定内容')),
                      for (final content in widget.contents)
                        DropdownMenuItem(
                          value: content.id,
                          child: Text(
                            content.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged:
                        (value) => setState(() => _contentId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MediaAssetType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: '媒体类型'),
                    items: [
                      for (final type in MediaAssetType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                    onChanged:
                        (value) => setState(
                          () => _type = value ?? MediaAssetType.image,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(labelText: '媒体 URL'),
                    validator: _validateUrl,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _filenameController,
                    decoration: const InputDecoration(labelText: '文件名'),
                    maxLength: 240,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contentTypeController,
                    decoration: const InputDecoration(labelText: 'MIME 类型'),
                    maxLength: 120,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AdminFormSection(
              title: '尺寸与容量',
              subtitle: '这些字段可选，用于媒体信息展示',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  AdminNumberField(
                    controller: _byteSizeController,
                    label: '字节数',
                  ),
                  AdminNumberField(controller: _widthController, label: '宽度'),
                  AdminNumberField(controller: _heightController, label: '高度'),
                  AdminNumberField(
                    controller: _durationController,
                    label: '时长秒',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入媒体 URL';
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) return '请输入完整 URL';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AdminMediaDraft(
        contentId: _contentId,
        type: _type,
        publicUrl: _urlController.text,
        filename: _filenameController.text,
        contentType: _contentTypeController.text,
        byteSize: parseNullableInt(_byteSizeController.text),
        width: parseNullableInt(_widthController.text),
        height: parseNullableInt(_heightController.text),
        durationSeconds: parseNullableInt(_durationController.text),
      ),
    );
  }
}
