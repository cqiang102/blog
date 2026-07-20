part of 'editor_main_panel.dart';

List<Widget> _buildEditorMetadataFields({
  required BuildContext context,
  required TextEditingController titleController,
  required TextEditingController summaryController,
  required ValueChanged<String> onTitleChanged,
  required ValueChanged<String> onSummaryChanged,
}) {
  return [
    TextFormField(
      key: const ValueKey('content-editor-title-field'),
      controller: titleController,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontSize: 18, height: 1.3),
      decoration: _editorMetadataDecoration(context, hintText: '标题'),
      maxLength: 180,
      buildCounter: _hideEditorLengthCounter,
      textInputAction: TextInputAction.next,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) =>
          value == null || value.trim().isEmpty ? '请输入标题' : null,
      onChanged: onTitleChanged,
    ),
    const SizedBox(height: AppSpacing.sm),
    TextFormField(
      key: const ValueKey('content-editor-summary-field'),
      controller: summaryController,
      decoration: _editorMetadataDecoration(context, hintText: '摘要（可选）'),
      minLines: 1,
      maxLines: 3,
      maxLength: 2000,
      buildCounter: _hideEditorLengthCounter,
      onChanged: onSummaryChanged,
    ),
  ];
}

InputDecoration _editorMetadataDecoration(
  BuildContext context, {
  required String hintText,
}) {
  final scheme = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(12);
  final enabledBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return InputDecoration(
    hintText: hintText,
    counterText: '',
    isDense: true,
    filled: true,
    fillColor: scheme.surfaceContainerLowest,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 12,
    ),
    border: enabledBorder,
    enabledBorder: enabledBorder,
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    ),
  );
}

Widget? _hideEditorLengthCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;
