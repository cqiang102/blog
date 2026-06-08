// 管理后台共享组件
// 包含工具栏、状态标签、错误面板、确认对话框等通用组件
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/models.dart';

/// 区域工具栏组件
/// 显示标题和操作按钮，支持主按钮和副按钮
class SectionToolbar extends StatelessWidget {
  const SectionToolbar({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondaryAction,
  });

  final String title; // 区域标题
  final String actionLabel; // 主按钮文本
  final IconData actionIcon; // 主按钮图标
  final VoidCallback onAction; // 主按钮点击回调
  final String? secondaryLabel; // 副按钮文本
  final IconData? secondaryIcon; // 副按钮图标
  final VoidCallback? onSecondaryAction; // 副按钮点击回调

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            if (secondaryLabel != null)
              OutlinedButton.icon(
                onPressed: onSecondaryAction,
                icon: Icon(secondaryIcon ?? Icons.add),
                label: Text(secondaryLabel!),
              ),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon),
              label: Text(actionLabel),
            ),
          ],
        ),
      ],
    );
  }
}

/// 数字输入框组件
/// 带数字验证的文本输入框
class AdminNumberField extends StatelessWidget {
  const AdminNumberField({super.key, required this.controller, required this.label});

  final TextEditingController controller; // 输入框控制器
  final String label; // 标签文本

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kAdminNumberFieldWidth,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return null;
          return int.tryParse(text) == null ? '请输入数字' : null;
        },
      ),
    );
  }
}

/// 内容状态标签组件
/// 根据状态显示不同颜色的标签
class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.status});

  final ContentStatus status; // 内容状态

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      ContentStatus.published => scheme.primaryContainer,
      ContentStatus.archived => scheme.errorContainer,
      ContentStatus.draft => scheme.secondaryContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

/// 评论状态标签组件
/// 根据评论状态显示不同颜色的标签
class AdminCommentStatusChip extends StatelessWidget {
  const AdminCommentStatusChip({super.key, required this.status});

  final AdminCommentStatus status; // 评论状态

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      AdminCommentStatus.visible => scheme.primaryContainer,
      AdminCommentStatus.deleted => scheme.errorContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

/// 用户角色标签组件
/// 根据用户角色显示不同颜色的标签
class AdminUserRoleChip extends StatelessWidget {
  const AdminUserRoleChip({super.key, required this.role});

  final AdminUserRole role; // 用户角色

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (role) {
      AdminUserRole.admin => scheme.tertiaryContainer,
      AdminUserRole.user => scheme.secondaryContainer,
    };
    return Chip(label: Text(role.label), backgroundColor: color);
  }
}

/// 用户状态标签组件
/// 根据用户状态显示不同颜色的标签
class AdminUserStatusChip extends StatelessWidget {
  const AdminUserStatusChip({super.key, required this.status});

  final AdminUserStatus status; // 用户状态

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      AdminUserStatus.active => scheme.primaryContainer,
      AdminUserStatus.disabled => scheme.errorContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

/// 元数据文本组件
/// 显示图标 + 文本的元数据信息
class AdminMetaText extends StatelessWidget {
  const AdminMetaText({super.key, required this.icon, required this.text});

  final IconData icon; // 图标
  final String text; // 文本

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(text)],
    );
  }
}

/// 媒体缩略图组件
/// 根据媒体类型显示缩略图或占位图标
class AdminMediaThumb extends StatelessWidget {
  const AdminMediaThumb({
    super.key,
    required this.url,
    required this.type,
    required this.size,
  });

  final String url; // 媒体 URL
  final MediaAssetType type; // 媒体类型
  final Size size; // 缩略图尺寸

  @override
  Widget build(BuildContext context) {
    final fallbackIcon = switch (type) {
      MediaAssetType.video => Icons.play_circle_outline,
      MediaAssetType.file => Icons.insert_drive_file_outlined,
      MediaAssetType.image => Icons.image_outlined,
    };
    final placeholder = SizedBox(
      width: size.width,
      height: size.height,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(fallbackIcon),
      ),
    );

    if (url.isEmpty || type != MediaAssetType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: placeholder,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size.width,
        height: size.height,
        fit: BoxFit.cover,
        memCacheWidth: size.width.toInt() * 2,
        errorWidget: (context, url, error) => placeholder,
      ),
    );
  }
}

/// 内联错误组件
/// 在列表中显示错误信息的卡片
class AdminInlineError extends StatelessWidget {
  const AdminInlineError({super.key, required this.message});

  final String message; // 错误信息

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

/// 错误面板组件
/// 居中显示错误信息和重试按钮
class AdminErrorPane extends StatelessWidget {
  const AdminErrorPane({super.key, required this.message, required this.onRetry});

  final String message; // 错误信息
  final VoidCallback onRetry; // 重试回调

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空面板组件
/// 数据为空时显示的提示信息
class AdminEmptyPane extends StatelessWidget {
  const AdminEmptyPane({super.key, required this.message});

  final String message; // 提示信息

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(child: Text(message)),
    );
  }
}

/// 确认对话框
/// 通用的确认操作对话框，返回用户是否确认
Future<bool> adminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
  );
  return confirmed == true;
}

/// 显示 SnackBar 提示
void showAdminSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// 格式化日期
/// 时间戳为 0 时返回"未发布"，否则返回 yyyy-MM-dd HH:mm 格式
String formatAdminDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) {
    return '未发布';
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(date);
}

/// 格式化字节数
/// 自动转换为 B/KB/MB/GB 单位
String formatAdminBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}

/// 解析可空整数
/// 空字符串返回 null，非空时尝试解析为 int
int? parseNullableInt(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

/// 根据文件名推断媒体类型
/// 视频：mp4/webm/mov；图片：jpg/jpeg/png/gif/webp；其他：file
MediaAssetType inferMediaType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mov')) {
    return MediaAssetType.video;
  }
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp')) {
    return MediaAssetType.image;
  }
  return MediaAssetType.file;
}
