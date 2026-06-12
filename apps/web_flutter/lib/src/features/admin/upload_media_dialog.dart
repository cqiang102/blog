// 媒体上传对话框
// 支持选择文件、填写标题和描述后上传到 MinIO
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/models.dart';
import '../../theme/app_spacing.dart';
import 'admin_widgets.dart';

/// 上传媒体草稿数据
class UploadMediaDraft {
  const UploadMediaDraft({required this.contentId, required this.type});

  final String contentId; // 绑定的内容 ID
  final MediaAssetType type; // 媒体类型
}

/// 上传媒体对话框
/// 选择文件后弹出，用于指定媒体类型和绑定内容
class UploadMediaDialog extends StatefulWidget {
  const UploadMediaDialog({
    super.key,
    required this.filename,
    required this.inferredType,
    required this.contents,
  });

  final String filename; // 文件名
  final MediaAssetType inferredType; // 根据文件名推断的媒体类型
  final List<AdminContentItem> contents; // 可绑定的内容列表

  @override
  State<UploadMediaDialog> createState() => UploadMediaDialogState();
}

/// 上传媒体对话框状态管理
class UploadMediaDialogState extends State<UploadMediaDialog> {
  late String _contentId;
  late MediaAssetType _type;

  @override
  void initState() {
    super.initState();
    _contentId = '';
    _type = widget.inferredType;
  }

  @override
  Widget build(BuildContext context) {
    return AdminEditorDialog(
      title: '上传文件',
      subtitle: '确认文件类型和关联内容后开始上传',
      maxWidth: 640,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed:
              () => Navigator.of(
                context,
              ).pop(UploadMediaDraft(contentId: _contentId, type: _type)),
          child: const Text('开始上传'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminFormSection(
            title: '文件信息',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const HugeIcon(icon: HugeIcons.strokeRoundedFile01),
                  title: Text(
                    widget.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('文件会上传到 MinIO 并自动写入媒体库'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AdminFormSection(
            title: '上传设置',
            child: Column(
              children: [
                const SizedBox(height: 12),
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
                      (value) =>
                          setState(() => _type = value ?? MediaAssetType.file),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
