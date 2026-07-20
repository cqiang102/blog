part of 'content_editor_page.dart';

class _ImagePickerDialog extends StatelessWidget {
  const _ImagePickerDialog({required this.mediaUrls, required this.onUpload});

  final List<String> mediaUrls;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = (viewport.width - 96).clamp(240.0, 560.0).toDouble();
    final dialogHeight = (viewport.height - 240).clamp(240.0, 420.0).toDouble();
    return AlertDialog(
      title: const Text('插入图片'),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: mediaUrls.length,
          itemBuilder: (context, index) {
            final url = mediaUrls[index];
            return Semantics(
              button: true,
              label: '插入图片 ${index + 1}',
              child: InkWell(
                onTap: () => Navigator.of(context).pop(url),
                borderRadius: BorderRadius.circular(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: resolveMediaUrl(url),
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: onUpload,
          icon: const Icon(Icons.upload_outlined),
          label: const Text('上传新图片'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

class _TableSpec {
  const _TableSpec({required this.columns, required this.rows});

  final int columns;
  final int rows;
}

class _TableEditorDialog extends StatefulWidget {
  const _TableEditorDialog();

  @override
  State<_TableEditorDialog> createState() => _TableEditorDialogState();
}

class _TableEditorDialogState extends State<_TableEditorDialog> {
  int _columns = 3;
  int _rows = 3;

  @override
  Widget build(BuildContext context) {
    final dialogWidth = (MediaQuery.sizeOf(context).width - 96)
        .clamp(240.0, 360.0)
        .toDouble();
    return AlertDialog(
      title: const Text('插入表格'),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TableStepper(
              label: '列数',
              value: _columns,
              min: 1,
              max: 8,
              onChanged: (value) => setState(() => _columns = value),
            ),
            const SizedBox(height: AppSpacing.md),
            _TableStepper(
              label: '正文行数',
              value: _rows,
              min: 1,
              max: 12,
              onChanged: (value) => setState(() => _rows = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_TableSpec(columns: _columns, rows: _rows)),
          child: const Text('插入'),
        ),
      ],
    );
  }
}

class _TableStepper extends StatelessWidget {
  const _TableStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: '减少',
          onPressed: value <= min ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: '增加',
          onPressed: value >= max ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
