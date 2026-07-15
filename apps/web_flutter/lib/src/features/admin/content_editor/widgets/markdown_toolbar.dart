import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../markdown_edit_command.dart';
import '../content_editor_state.dart';

/// Markdown 工具栏
/// 提供常用的 Markdown 格式化按钮、标题选择、编辑模式切换
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.onAction,
    this.onSetEditMode,
    this.editMode = EditorEditMode.source,
    this.onInsertImage,
    this.onInsertCodeBlockLanguage,
    this.onOpenTableEditor,
  });

  /// 应用 Markdown 编辑命令的回调
  final ValueChanged<MarkdownEditAction> onAction;

  /// 设置编辑模式的回调
  final void Function(EditorEditMode mode)? onSetEditMode;

  /// 当前编辑模式
  final EditorEditMode editMode;

  /// 插入图片的回调
  final VoidCallback? onInsertImage;

  /// 插入或更新代码块语言
  final ValueChanged<String>? onInsertCodeBlockLanguage;

  /// 打开表格编辑器
  final VoidCallback? onOpenTableEditor;

  @override
  Widget build(BuildContext context) {
    final editingEnabled = editMode != EditorEditMode.preview;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (editingEnabled) ...[
          _ToolbarButton(
            icon: HugeIcons.strokeRoundedTextBold,
            tooltip: '粗体 (Ctrl/⌘ B)',
            onPressed: () => onAction(MarkdownEditAction.bold),
          ),
          _ToolbarButton(
            icon: HugeIcons.strokeRoundedTextItalic,
            tooltip: '斜体 (Ctrl/⌘ I)',
            onPressed: () => onAction(MarkdownEditAction.italic),
          ),
          _ToolbarButton(
            icon: HugeIcons.strokeRoundedTextStrikethrough,
            tooltip: '删除线',
            onPressed: () => onAction(MarkdownEditAction.strikethrough),
          ),
          const _Divider(),
          _HeadingMenu(onAction: onAction),
          const _Divider(),
          _ToolbarButton(
            icon: HugeIcons.strokeRoundedLeftToRightListBullet,
            tooltip: '无序列表 (Ctrl/⌘ Shift U)',
            onPressed: () => onAction(MarkdownEditAction.unorderedList),
          ),
          _ToolbarButton(
            icon: HugeIcons.strokeRoundedLeftToRightListNumber,
            tooltip: '有序列表 (Ctrl/⌘ Shift O)',
            onPressed: () => onAction(MarkdownEditAction.orderedList),
          ),
          _ToolbarButton(
            icon: HugeIcons.strokeRoundedCheckList,
            tooltip: '任务列表',
            onPressed: () => onAction(MarkdownEditAction.taskList),
          ),
          _ToolbarButton(
            icon: HugeIcons.strokeRoundedLeftToRightBlockQuote,
            tooltip: '引用 (Ctrl/⌘ Shift Q)',
            onPressed: () => onAction(MarkdownEditAction.quote),
          ),
          const _Divider(),
          _ToolbarButton(
            icon: HugeIcons.strokeRoundedCode,
            tooltip: '行内代码',
            onPressed: () => onAction(MarkdownEditAction.inlineCode),
          ),
          _CodeBlockMenu(onInsertLanguage: onInsertCodeBlockLanguage),
          _ToolbarButton(
            icon: HugeIcons.strokeRoundedLink01,
            tooltip: '链接 (Ctrl/⌘ K)',
            onPressed: () => onAction(MarkdownEditAction.link),
          ),
          const _Divider(),
          _ToolbarButton(
            icon: HugeIcons.strokeRoundedImage01,
            tooltip: '插入图片',
            onPressed: onInsertImage,
          ),
          _TableMenu(onAction: onAction, onOpenTableEditor: onOpenTableEditor),
          _ToolbarButton(
            icon: HugeIcons.strokeRoundedSeparatorHorizontal,
            tooltip: '分割线',
            onPressed: () => onAction(MarkdownEditAction.horizontalRule),
          ),
        ],

        if (onSetEditMode != null) ...[
          if (editingEnabled) const _Divider(),
          // 编辑模式切换
          _EditModeSelector(editMode: editMode, onSetEditMode: onSetEditMode!),
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
          icon: HugeIcon(icon: HugeIcons.strokeRoundedCode, size: 16),
          tooltip: '源码模式',
        ),
        ButtonSegment(
          value: EditorEditMode.split,
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedVerticalScrollPoint,
            size: 16,
          ),
          tooltip: '实时预览模式',
        ),
        ButtonSegment(
          value: EditorEditMode.preview,
          icon: HugeIcon(icon: HugeIcons.strokeRoundedView, size: 16),
          tooltip: '纯预览模式',
        ),
      ],
      selected: {editMode},
      showSelectedIcon: false,
      onSelectionChanged: (modes) => onSetEditMode(modes.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        minimumSize: WidgetStateProperty.all(const Size(0, 40)),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
    );
  }
}

/// 代码块语言菜单
class _CodeBlockMenu extends StatelessWidget {
  const _CodeBlockMenu({required this.onInsertLanguage});

  final ValueChanged<String>? onInsertLanguage;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '代码块 (Ctrl/⌘ Shift C)',
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: HugeIcon(icon: HugeIcons.strokeRoundedCodeSquare, size: 20),
      ),
      onSelected: (language) {
        onInsertLanguage?.call(language);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: '', child: Text('纯文本代码块')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'bash', child: Text('Bash / Shell')),
        PopupMenuItem(value: 'cpp', child: Text('C / C++')),
        PopupMenuItem(value: 'css', child: Text('CSS')),
        PopupMenuItem(value: 'dart', child: Text('Dart / Flutter')),
        PopupMenuItem(value: 'diff', child: Text('Diff')),
        PopupMenuItem(value: 'dockerfile', child: Text('Dockerfile')),
        PopupMenuItem(value: 'go', child: Text('Go')),
        PopupMenuItem(value: 'java', child: Text('Java')),
        PopupMenuItem(value: 'javascript', child: Text('JavaScript')),
        PopupMenuItem(value: 'json', child: Text('JSON')),
        PopupMenuItem(value: 'kotlin', child: Text('Kotlin')),
        PopupMenuItem(value: 'markdown', child: Text('Markdown')),
        PopupMenuItem(value: 'nginx', child: Text('Nginx')),
        PopupMenuItem(value: 'python', child: Text('Python')),
        PopupMenuItem(value: 'rust', child: Text('Rust')),
        PopupMenuItem(value: 'sql', child: Text('SQL')),
        PopupMenuItem(value: 'swift', child: Text('Swift')),
        PopupMenuItem(value: 'typescript', child: Text('TypeScript')),
        PopupMenuItem(value: 'xml', child: Text('XML / HTML')),
        PopupMenuItem(value: 'yaml', child: Text('YAML')),
      ],
    );
  }
}

/// 标题下拉菜单
class _HeadingMenu extends StatelessWidget {
  const _HeadingMenu({required this.onAction});

  final ValueChanged<MarkdownEditAction> onAction;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '标题',
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedText, size: 20),
            SizedBox(width: 4),
            HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01, size: 16),
          ],
        ),
      ),
      onSelected: (level) {
        onAction(switch (level) {
          1 => MarkdownEditAction.heading1,
          2 => MarkdownEditAction.heading2,
          3 => MarkdownEditAction.heading3,
          4 => MarkdownEditAction.heading4,
          5 => MarkdownEditAction.heading5,
          _ => MarkdownEditAction.heading6,
        });
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
        const PopupMenuItem(value: 4, child: Text('四级标题')),
        const PopupMenuItem(value: 5, child: Text('五级标题')),
        const PopupMenuItem(value: 6, child: Text('六级标题')),
      ],
    );
  }
}

/// 表格下拉菜单
class _TableMenu extends StatelessWidget {
  const _TableMenu({required this.onAction, required this.onOpenTableEditor});

  final ValueChanged<MarkdownEditAction> onAction;
  final VoidCallback? onOpenTableEditor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '表格',
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedTable, size: 20),
            SizedBox(width: 4),
            HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01, size: 16),
          ],
        ),
      ),
      onSelected: (value) {
        if (value == 'custom') {
          onOpenTableEditor?.call();
          return;
        }
        switch (value) {
          case '2x2':
            onAction(MarkdownEditAction.table2x2);
          case '3x3':
            onAction(MarkdownEditAction.table3x3);
          case '4x4':
            onAction(MarkdownEditAction.table4x4);
        }
      },
      itemBuilder: (context) => [
        if (onOpenTableEditor != null)
          const PopupMenuItem(value: 'custom', child: Text('自定义表格…')),
        if (onOpenTableEditor != null) const PopupMenuDivider(),
        const PopupMenuItem(value: '2x2', child: Text('2×2 表格')),
        const PopupMenuItem(value: '3x3', child: Text('3×3 表格')),
        const PopupMenuItem(value: '4x4', child: Text('4×4 表格')),
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

  final List<List<dynamic>> icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: HugeIcon(icon: icon, size: 20),
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
