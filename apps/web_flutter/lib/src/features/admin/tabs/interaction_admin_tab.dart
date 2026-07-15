// 管理后台 - 点赞和浏览记录标签页
// 展示点赞记录和浏览记录，支持筛选
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../state/state.dart';
import '../../../core/models.dart';
import '../admin_widgets.dart';

/// 管理后台 - 点赞管理标签页
/// 支持点赞记录的筛选和删除
class AdminLikeTab extends ConsumerStatefulWidget {
  const AdminLikeTab({super.key});

  @override
  ConsumerState<AdminLikeTab> createState() => AdminLikeTabState();
}

/// 点赞管理标签页状态管理
class AdminLikeTabState extends ConsumerState<AdminLikeTab> {
  final _contentIdController = TextEditingController(); // 内容 ID 筛选框
  final _userIdController = TextEditingController(); // 用户 ID 筛选框
  AdminRecordQuery _query = const AdminRecordQuery(); // 当前查询条件

  @override
  void dispose() {
    _contentIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final likes = ref.watch(adminLikesProvider(_query));

    return likes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminLikesProvider(_query)),
      ),
      data: (page) => ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: page.items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RecordFilters(
                  contentIdController: _contentIdController,
                  userIdController: _userIdController,
                  onApply: _applyFilters,
                  onClear: _clearFilters,
                ),
                const SizedBox(height: 12),
                Text(
                  '共 ${page.total} 条点赞记录',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (page.items.isEmpty) const AdminEmptyPane(message: '暂无点赞记录'),
              ],
            );
          }
          final like = page.items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LikeAdminRow(
              like: like,
              onDelete: () => _deleteLike(context, like),
            ),
          );
        },
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminRecordQuery(
        contentId: _contentIdController.text.trim(),
        userId: _userIdController.text.trim(),
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _contentIdController.clear();
      _userIdController.clear();
      _query = const AdminRecordQuery();
    });
  }

  Future<void> _deleteLike(BuildContext context, AdminLikeItem like) async {
    if (!mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '删除点赞记录',
      message: '确认删除这条点赞记录？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminLike(accessToken: token, id: like.id);
      _refreshLikeState(like.contentId);
      if (!context.mounted) return;
      showAdminSnack(context, '点赞记录已删除');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  void _refreshLikeState(String contentId) {
    ref.invalidate(adminLikesProvider(_query));
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(contentDetailProvider(contentId));
    ref.invalidate(recommendationsProvider);
  }
}

/// 管理后台 - 浏览记录管理标签页
/// 支持浏览记录的筛选和删除
class AdminViewTab extends ConsumerStatefulWidget {
  const AdminViewTab({super.key});

  @override
  ConsumerState<AdminViewTab> createState() => AdminViewTabState();
}

/// 浏览记录管理标签页状态管理
class AdminViewTabState extends ConsumerState<AdminViewTab> {
  final _contentIdController = TextEditingController(); // 内容 ID 筛选框
  final _userIdController = TextEditingController(); // 用户 ID 筛选框
  AdminRecordQuery _query = const AdminRecordQuery(); // 当前查询条件

  @override
  void dispose() {
    _contentIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(adminViewsProvider(_query));

    return views.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminViewsProvider(_query)),
      ),
      data: (page) => ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: page.items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RecordFilters(
                  contentIdController: _contentIdController,
                  userIdController: _userIdController,
                  onApply: _applyFilters,
                  onClear: _clearFilters,
                ),
                const SizedBox(height: 12),
                Text(
                  '共 ${page.total} 条浏览记录',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (page.items.isEmpty) const AdminEmptyPane(message: '暂无浏览记录'),
              ],
            );
          }
          final view = page.items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ViewAdminRow(
              view: view,
              onDelete: () => _deleteView(context, view),
            ),
          );
        },
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminRecordQuery(
        contentId: _contentIdController.text.trim(),
        userId: _userIdController.text.trim(),
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _contentIdController.clear();
      _userIdController.clear();
      _query = const AdminRecordQuery();
    });
  }

  Future<void> _deleteView(
    BuildContext context,
    AdminViewRecordItem view,
  ) async {
    if (!mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '删除浏览记录',
      message: '确认删除这条浏览记录？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminView(accessToken: token, id: view.id);
      _refreshViewState(view.contentId);
      if (!context.mounted) return;
      showAdminSnack(context, '浏览记录已删除');
    } on ApiException catch (error) {
      showAdminSnack(context, error.message);
    } catch (error) {
      showAdminSnack(context, error.toString());
    }
  }

  void _refreshViewState(String contentId) {
    ref.invalidate(adminViewsProvider(_query));
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(contentDetailProvider(contentId));
  }
}

/// 记录筛选组件
/// 点赞和浏览记录共用的筛选 UI（内容 ID + 用户 ID）
class _RecordFilters extends StatelessWidget {
  const _RecordFilters({
    required this.contentIdController,
    required this.userIdController,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController contentIdController; // 内容 ID 控制器
  final TextEditingController userIdController; // 用户 ID 控制器
  final VoidCallback onApply; // 应用筛选回调
  final VoidCallback onClear; // 清空筛选回调

  @override
  Widget build(BuildContext context) {
    return AdminFilterBar(
      items: [
        AdminFilterItem(
          child: TextField(
            controller: contentIdController,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(context, hintText: '内容 ID'),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onApply(),
          ),
        ),
        AdminFilterItem(
          child: TextField(
            controller: userIdController,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(context, hintText: '用户 ID'),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onApply(),
          ),
        ),
      ],
      actions: [
        AdminFilterApplyButton(onPressed: onApply),
        AdminFilterClearButton(onPressed: onClear),
      ],
    );
  }
}

/// 点赞管理行组件
/// 展示单条点赞记录的内容标题、用户信息和删除按钮
class _LikeAdminRow extends StatelessWidget {
  const _LikeAdminRow({required this.like, required this.onDelete});

  final AdminLikeItem like; // 点赞数据
  final VoidCallback onDelete; // 删除回调

  @override
  Widget build(BuildContext context) {
    final createdAt = formatAdminDate(like.createdAt);
    final userLabel = like.userNickname.isEmpty
        ? like.userEmail
        : like.userNickname;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HugeIcon(icon: HugeIcons.strokeRoundedFavourite),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => context.go('/contents/${like.contentId}'),
                    child: Text(
                      like.contentTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AdminRowFooter(
              metadata: [
                AdminMetaText(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedUser,
                    size: 18,
                  ),
                  text: userLabel,
                ),
                if (like.userEmail.isNotEmpty)
                  AdminMetaText(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedMail01,
                      size: 18,
                    ),
                    text: like.userEmail,
                  ),
                AdminMetaText(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedClock01,
                    size: 18,
                  ),
                  text: createdAt,
                ),
              ],
              actions: [
                TextButton.icon(
                  onPressed: onDelete,
                  style: adminCompactButtonStyle(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete01,
                    size: 18,
                  ),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 浏览记录管理行组件
/// 展示单条浏览记录的内容标题、用户信息、User-Agent 和删除按钮
class _ViewAdminRow extends StatelessWidget {
  const _ViewAdminRow({required this.view, required this.onDelete});

  final AdminViewRecordItem view; // 浏览记录数据
  final VoidCallback onDelete; // 删除回调

  @override
  Widget build(BuildContext context) {
    final createdAt = formatAdminDate(view.createdAt);
    final userLabel = view.anonymous
        ? '匿名访客'
        : (view.userNickname.isEmpty ? view.userEmail : view.userNickname);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HugeIcon(icon: HugeIcons.strokeRoundedClock01),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => context.go('/contents/${view.contentId}'),
                    child: Text(
                      view.contentTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (view.userAgent.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                view.userAgent,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            AdminRowFooter(
              metadata: [
                AdminMetaText(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedUser,
                    size: 18,
                  ),
                  text: userLabel,
                ),
                if (view.userEmail.isNotEmpty)
                  AdminMetaText(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedMail01,
                      size: 18,
                    ),
                    text: view.userEmail,
                  ),
                if (view.anonymousId.isNotEmpty)
                  AdminMetaText(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedFingerPrint,
                      size: 18,
                    ),
                    text: view.anonymousId,
                  ),
                AdminMetaText(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedClock01,
                    size: 18,
                  ),
                  text: createdAt,
                ),
              ],
              actions: [
                TextButton.icon(
                  onPressed: onDelete,
                  style: adminCompactButtonStyle(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete01,
                    size: 18,
                  ),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
