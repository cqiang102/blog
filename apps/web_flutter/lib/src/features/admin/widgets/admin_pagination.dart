import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/models.dart';

/// Corrects an out-of-range page after a mutation removes the last row.
mixin AdminPageCorrectionMixin<T extends StatefulWidget> on State<T> {
  bool _correctingAdminPage = false;

  void correctAdminPage<TItem>(
    PageResult<TItem> result, {
    required int requestedPage,
    required ValueChanged<int> onChanged,
  }) {
    if (_correctingAdminPage ||
        requestedPage <= 0 ||
        result.items.isNotEmpty ||
        result.total <= 0) {
      return;
    }

    final pageSize = result.size > 0 ? result.size : 1;
    final lastPage = (result.total - 1) ~/ pageSize;
    if (requestedPage <= lastPage) return;

    _correctingAdminPage = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _correctingAdminPage = false;
      if (mounted) onChanged(lastPage);
    });
  }
}

/// Shared pagination controls for all paged admin lists.
///
/// [page] is zero-based, while the labels shown to the user are one-based.
class AdminPaginationBar extends StatelessWidget {
  const AdminPaginationBar({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onChanged,
    super.key,
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final safePageSize = pageSize > 0 ? pageSize : 1;
    final totalPages = (total / safePageSize).ceil().clamp(1, 1 << 20);
    final currentPage = page.clamp(0, totalPages - 1);
    final visiblePages = <int>{
      0,
      totalPages - 1,
      for (var value = currentPage - 1; value <= currentPage + 1; value++)
        value,
    }.where((value) => value >= 0 && value < totalPages).toList()..sort();

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        IconButton.outlined(
          tooltip: '上一页',
          onPressed: currentPage > 0 ? () => onChanged(currentPage - 1) : null,
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            size: 18,
          ),
        ),
        for (var index = 0; index < visiblePages.length; index++) ...[
          if (index > 0 && visiblePages[index] - visiblePages[index - 1] > 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('…'),
            ),
          if (visiblePages[index] == currentPage)
            FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: Theme.of(context).colorScheme.primary,
                disabledForegroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimary,
                minimumSize: const Size(42, 42),
                padding: EdgeInsets.zero,
              ),
              child: Text('${visiblePages[index] + 1}'),
            )
          else
            OutlinedButton(
              onPressed: () => onChanged(visiblePages[index]),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(42, 42),
                padding: EdgeInsets.zero,
              ),
              child: Text('${visiblePages[index] + 1}'),
            ),
        ],
        IconButton.outlined(
          tooltip: '下一页',
          onPressed: currentPage + 1 < totalPages
              ? () => onChanged(currentPage + 1)
              : null,
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            size: 18,
          ),
        ),
      ],
    );
  }
}
