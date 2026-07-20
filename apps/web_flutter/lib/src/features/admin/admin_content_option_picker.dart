import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/models.dart';
import '../../state/state.dart';
import '../../theme/app_spacing.dart';
import 'admin_widgets.dart';

/// Searchable, remotely paged content selector shared by media dialogs.
class AdminContentOptionPicker extends ConsumerStatefulWidget {
  const AdminContentOptionPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.initialOption,
  });

  final String value;
  final AdminContentOption? initialOption;
  final ValueChanged<String> onChanged;

  @override
  ConsumerState<AdminContentOptionPicker> createState() =>
      _AdminContentOptionPickerState();
}

class _AdminContentOptionPickerState
    extends ConsumerState<AdminContentOptionPicker> {
  static const _debounceDuration = Duration(milliseconds: 300);

  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  AdminContentOptionsQuery _query = const AdminContentOptionsQuery(size: 10);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(adminContentOptionsProvider(_query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: '搜索绑定内容',
            prefixIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              size: 20,
            ),
          ),
          onChanged: _scheduleSearch,
        ),
        const SizedBox(height: AppSpacing.sm),
        options.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Row(
            children: [
              Expanded(
                child: AdminInlineError(message: adminErrorMessage(error)),
              ),
              IconButton(
                tooltip: '重试内容选项',
                onPressed: () =>
                    ref.invalidate(adminContentOptionsProvider(_query)),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  size: 20,
                ),
              ),
            ],
          ),
          data: _buildOptions,
        ),
      ],
    );
  }

  Widget _buildOptions(PageResult<AdminContentOption> page) {
    final optionsById = <String, AdminContentOption>{};
    final initialOption = widget.initialOption;
    if (initialOption != null && initialOption.id.isNotEmpty) {
      optionsById[initialOption.id] = initialOption;
    }
    for (final option in page.items) {
      optionsById[option.id] = option;
    }

    final selectedValue = widget.value.isEmpty ? '' : widget.value;
    if (selectedValue.isNotEmpty && !optionsById.containsKey(selectedValue)) {
      optionsById[selectedValue] = AdminContentOption(
        id: selectedValue,
        title: '当前绑定内容',
      );
    }

    final pageCount = page.total == 0
        ? 1
        : (page.total + page.size - 1) ~/ page.size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('$selectedValue:${optionsById.keys.join(',')}'),
          initialValue: selectedValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '绑定内容'),
          items: [
            const DropdownMenuItem(value: '', child: Text('不绑定内容')),
            for (final option in optionsById.values)
              DropdownMenuItem(
                value: option.id,
                child: Text(
                  option.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => widget.onChanged(value ?? ''),
        ),
        if (pageCount > 1) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: '上一页内容',
                onPressed: page.page > 0
                    ? () => _changePage(page.page - 1)
                    : null,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 20,
                ),
              ),
              Text('${page.page + 1} / $pageCount'),
              IconButton(
                tooltip: '下一页内容',
                onPressed: page.page + 1 < pageCount
                    ? () => _changePage(page.page + 1)
                    : null,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      setState(() {
        _query = _query.copyWith(query: value.trim(), page: 0);
      });
    });
  }

  void _changePage(int page) {
    if (page < 0 || page == _query.page) return;
    setState(() => _query = _query.copyWith(page: page));
  }
}
