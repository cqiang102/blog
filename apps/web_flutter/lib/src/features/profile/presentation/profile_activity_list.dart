part of 'profile_view.dart';

// ============================================================================
// 活动记录列表组件
// ============================================================================

class _RecordList extends ConsumerStatefulWidget {
  const _RecordList({required this.type, required this.label});

  final ProfileActivityType type;
  final String label;

  @override
  ConsumerState<_RecordList> createState() => _RecordListState();
}

class _RecordListState extends ConsumerState<_RecordList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - kScrollThreshold) {
      _controller().loadMore();
    }
  }

  ProfileActivityState _watchState() {
    return ref.watch(profileActivityProvider(widget.type));
  }

  ProfileActivityController _controller() {
    return ref.read(profileActivityProvider(widget.type).notifier);
  }

  @override
  Widget build(BuildContext context) {
    final state = _watchState();
    if (state.items.isEmpty && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm + 4),
            FilledButton.icon(
              onPressed: _controller().retry,
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Text(
          '暂无${widget.label}记录',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = state.items[index];
        final date = DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt);
        return Card(
          key: ValueKey(item.id),
          child: ListTile(
            title: Text(item.title),
            subtitle: Text(date),
            onTap: () => context.go('/contents/${item.contentId}'),
            trailing: IconButton(
              tooltip: '删除',
              onPressed: () => _delete(item),
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete01),
            ),
          ),
        );
      },
    );
  }

  /// 删除活动记录
  Future<void> _delete(UserActivity item) async {
    final error = await _controller().delete(item);
    if (mounted && error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
