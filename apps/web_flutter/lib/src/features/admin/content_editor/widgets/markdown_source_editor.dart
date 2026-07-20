part of 'editor_main_panel.dart';

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
