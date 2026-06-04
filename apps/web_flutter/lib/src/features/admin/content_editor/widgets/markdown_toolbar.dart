import 'package:flutter/material.dart';

/// Markdown 工具栏
/// 提供常用的 Markdown 格式化按钮
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.onInsert,
    this.onTogglePreview,
    this.showPreview = false,
  });

  /// 插入 Markdown 语法的回调
  final void Function(String prefix, String suffix) onInsert;

  /// 切换预览模式的回调
  final VoidCallback? onTogglePreview;

  /// 是否显示预览按钮
  final bool showPreview;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToolbarButton(
          icon: Icons.format_bold,
          tooltip: '粗体',
          onPressed: () => onInsert('**', '**'),
        ),
        _ToolbarButton(
          icon: Icons.format_italic,
          tooltip: '斜体',
          onPressed: () => onInsert('*', '*'),
        ),
        _ToolbarButton(
          icon: Icons.title,
          tooltip: '标题',
          onPressed: () => onInsert('\n## ', '\n'),
        ),
        _ToolbarButton(
          icon: Icons.link,
          tooltip: '链接',
          onPressed: () => onInsert('[', '](url)'),
        ),
        _ToolbarButton(
          icon: Icons.code,
          tooltip: '代码',
          onPressed: () => onInsert('`', '`'),
        ),
        _ToolbarButton(
          icon: Icons.format_quote,
          tooltip: '引用',
          onPressed: () => onInsert('\n> ', '\n'),
        ),
        _ToolbarButton(
          icon: Icons.format_list_bulleted,
          tooltip: '列表',
          onPressed: () => onInsert('\n- ', '\n'),
        ),
        if (onTogglePreview != null) ...[
          const SizedBox(width: 8),
          const VerticalDivider(),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(showPreview ? Icons.edit : Icons.preview),
            tooltip: showPreview ? '编辑' : '预览',
            onPressed: onTogglePreview,
          ),
        ],
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
