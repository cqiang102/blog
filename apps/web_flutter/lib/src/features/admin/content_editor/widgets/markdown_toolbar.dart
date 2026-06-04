import 'package:flutter/material.dart';

import '../content_editor_state.dart';

/// Markdown 工具栏
/// 提供常用的 Markdown 格式化按钮、标题选择、编辑模式切换
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.onInsert,
    this.onSetEditMode,
    this.editMode = EditorEditMode.source,
    this.onInsertImage,
    this.mediaUrls = const [],
  });

  /// 插入 Markdown 语法的回调
  final void Function(String prefix, String suffix) onInsert;

  /// 设置编辑模式的回调
  final void Function(EditorEditMode mode)? onSetEditMode;

  /// 当前编辑模式
  final EditorEditMode editMode;

  /// 插入图片的回调
  final VoidCallback? onInsertImage;

  /// 已上传的媒体 URL 列表
  final List<String> mediaUrls;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 格式化按钮
        _ToolbarButton(
          icon: Icons.format_bold,
          tooltip: '粗体 (Ctrl+B)',
          onPressed: () => onInsert('**', '**'),
        ),
        _ToolbarButton(
          icon: Icons.format_italic,
          tooltip: '斜体 (Ctrl+I)',
          onPressed: () => onInsert('*', '*'),
        ),
        _ToolbarButton(
          icon: Icons.strikethrough_s,
          tooltip: '删除线',
          onPressed: () => onInsert('~~', '~~'),
        ),
        const _Divider(),

        // 标题下拉菜单
        _HeadingMenu(onInsert: onInsert),
        const _Divider(),

        // 列表和引用
        _ToolbarButton(
          icon: Icons.format_list_bulleted,
          tooltip: '无序列表',
          onPressed: () => onInsert('\n- ', '\n'),
        ),
        _ToolbarButton(
          icon: Icons.format_list_numbered,
          tooltip: '有序列表',
          onPressed: () => onInsert('\n1. ', '\n'),
        ),
        _ToolbarButton(
          icon: Icons.checklist,
          tooltip: '任务列表',
          onPressed: () => onInsert('\n- [ ] ', '\n'),
        ),
        _ToolbarButton(
          icon: Icons.format_quote,
          tooltip: '引用',
          onPressed: () => onInsert('\n> ', '\n'),
        ),
        const _Divider(),

        // 代码和链接
        _ToolbarButton(
          icon: Icons.code,
          tooltip: '行内代码',
          onPressed: () => onInsert('`', '`'),
        ),
        _ToolbarButton(
          icon: Icons.integration_instructions,
          tooltip: '代码块',
          onPressed: () => onInsert('\n```\n', '\n```\n'),
        ),
        _ToolbarButton(
          icon: Icons.link,
          tooltip: '链接',
          onPressed: () => onInsert('[', '](url)'),
        ),
        const _Divider(),

        // 图片
        _ToolbarButton(
          icon: Icons.image,
          tooltip: '插入图片',
          onPressed: onInsertImage,
        ),

        // 表格
        _TableMenu(onInsert: onInsert),

        // 分割线
        _ToolbarButton(
          icon: Icons.horizontal_rule,
          tooltip: '分割线',
          onPressed: () => onInsert('\n---\n', ''),
        ),

        if (onSetEditMode != null) ...[
          const _Divider(),
          // 编辑模式切换
          _EditModeSelector(
            editMode: editMode,
            onSetEditMode: onSetEditMode!,
          ),
        ],
      ],
    );
  }
}

/// 编辑模式选择器
class _EditModeSelector extends StatelessWidget {
  const _EditModeSelector({
    required this.editMode,
    required this.onSetEditMode,
  });

  final EditorEditMode editMode;
  final void Function(EditorEditMode mode) onSetEditMode;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<EditorEditMode>(
      segments: const [
        ButtonSegment(
          value: EditorEditMode.source,
          icon: Icon(Icons.code, size: 16),
          tooltip: '源码模式',
        ),
        ButtonSegment(
          value: EditorEditMode.split,
          icon: Icon(Icons.vertical_split, size: 16),
          tooltip: '分屏模式',
        ),
        ButtonSegment(
          value: EditorEditMode.preview,
          icon: Icon(Icons.preview, size: 16),
          tooltip: '预览模式',
        ),
      ],
      selected: {editMode},
      onSelectionChanged: (modes) => onSetEditMode(modes.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }
}

/// 标题下拉菜单
class _HeadingMenu extends StatelessWidget {
  const _HeadingMenu({required this.onInsert});

  final void Function(String prefix, String suffix) onInsert;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '标题',
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.title, size: 20),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      onSelected: (level) {
        final prefix = '\n${'#' * level} ';
        onInsert(prefix, '\n');
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 1,
          child: Text('一级标题', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const PopupMenuItem(
          value: 2,
          child: Text('二级标题', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const PopupMenuItem(
          value: 3,
          child: Text('三级标题', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const PopupMenuItem(
          value: 4,
          child: Text('四级标题'),
        ),
        const PopupMenuItem(
          value: 5,
          child: Text('五级标题'),
        ),
        const PopupMenuItem(
          value: 6,
          child: Text('六级标题'),
        ),
      ],
    );
  }
}

/// 表格下拉菜单
class _TableMenu extends StatelessWidget {
  const _TableMenu({required this.onInsert});

  final void Function(String prefix, String suffix) onInsert;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '表格',
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_chart, size: 20),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      onSelected: (value) {
        switch (value) {
          case '2x2':
            onInsert(
              '\n| 列1 | 列2 |\n| --- | --- |\n| 内容 | 内容 |\n',
              '',
            );
          case '3x3':
            onInsert(
              '\n| 列1 | 列2 | 列3 |\n| --- | --- | --- |\n| 内容 | 内容 | 内容 |\n',
              '',
            );
          case '4x4':
            onInsert(
              '\n| 列1 | 列2 | 列3 | 列4 |\n| --- | --- | --- | --- |\n| 内容 | 内容 | 内容 | 内容 |\n',
              '',
            );
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: '2x2',
          child: Text('2×2 表格'),
        ),
        const PopupMenuItem(
          value: '3x3',
          child: Text('3×3 表格'),
        ),
        const PopupMenuItem(
          value: '4x4',
          child: Text('4×4 表格'),
        ),
      ],
    );
  }
}

/// 工具栏按钮
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
    );
  }
}

/// 分隔线
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 24,
      child: VerticalDivider(width: 16, thickness: 1),
    );
  }
}
