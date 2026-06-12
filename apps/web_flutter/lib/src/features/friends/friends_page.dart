// 友链页模块
// 展示友链网格，包含头像、名称、简介，点击跳转外部链接
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/state.dart';
import '../../widgets/widgets.dart';
import '../../core/constants.dart';
import '../../core/models.dart';
import '../../theme/app_spacing.dart';

/// 友链页 Widget
/// 从 API 加载友链列表，以响应式网格展示
class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider); // 获取友链数据

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          title: Text('朋友们'),
          actions: [AppThemeToggle(), SizedBox(width: AppSpacing.sm)],
        ),
        friends.when(
          loading:
              () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, stackTrace) => SliverFillRemaining(
                child: _FriendsError(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(friendsProvider),
                ),
              ),
          data: (items) {
            if (items.isEmpty) {
              return const SliverFillRemaining(
                child: Center(child: Text('暂无朋友链接')),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverGrid.builder(
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: kFriendCardMaxWidth,
                  mainAxisExtent: kFriendCardHeight,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  return _FriendCard(friend: items[index])
                      .fadeSlideIn(delay: (index * 80).ms);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 友链卡片组件
/// 展示单个友链的头像、名称、简介，点击在新窗口打开链接
class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friend});

  final FriendLink friend; // 友链数据

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap:
            () => launchUrl(
              Uri.parse(friend.siteUrl),
              webOnlyWindowName: '_blank',
            ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage:
                        friend.avatarUrl.isEmpty
                            ? null
                            : NetworkImage(friend.avatarUrl),
                    radius: 28,
                    child:
                        friend.avatarUrl.isEmpty
                            ? Text(
                              friend.name.isEmpty
                                  ? '?'
                                  : friend.name.substring(0, 1),
                            )
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      friend.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const HugeIcon(icon: HugeIcons.strokeRoundedLink01),
                ],
              ),
              const SizedBox(height: 16),
              Text(friend.intro, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (friend.updatedAt case final updatedAt?) ...[
                const Spacer(),
                Text(
                  '更新于 ${DateFormat('yyyy-MM-dd').format(updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 友链错误组件
/// 加载友链失败时显示错误信息和重试按钮
class _FriendsError extends StatelessWidget {
  const _FriendsError({required this.message, required this.onRetry});

  final String message; // 错误信息
  final VoidCallback onRetry; // 重试回调

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
