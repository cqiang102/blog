part of '../content_detail_page.dart';

class _CommentList extends ConsumerWidget {
  const _CommentList({required this.comments, required this.contentId});

  final List<CommentItem> comments;
  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (comments.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Text('暂无评论'),
        ),
      );
    }

    final auth = ref.watch(authControllerProvider);

    return SliverList.builder(
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Column(
          children: [
            Padding(
              key: ValueKey(comment.id),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CommentAvatar(avatarUrl: comment.authorAvatarUrl),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              comment.authorNickname,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              _formatTime(comment.createdAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const Spacer(),
                            if (auth.isAuthenticated &&
                                auth.user?.id == comment.authorId)
                              IconButton(
                                tooltip: '删除评论',
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _deleteComment(context, ref, comment),
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedDelete01,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (comment.blocked)
                          Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedBlocked,
                                size: 14,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '评论审核中，暂不可见',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            comment.body,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ).fadeSlideIn(delay: (index * 60).ms),
            if (index < comments.length - 1) const Divider(height: 1),
          ],
        );
      },
    );
  }

  Future<void> _deleteComment(
    BuildContext context,
    WidgetRef ref,
    CommentItem comment,
  ) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteComment(accessToken: token, commentId: comment.id);
      ref.invalidate(commentsProvider(contentId));
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// 格式化时间为相对时间
  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30} 个月前';
    return '${diff.inDays ~/ 365} 年前';
  }
}

/// 评论头像组件
class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final resolved = avatarUrl != null && avatarUrl!.isNotEmpty
        ? resolveMediaUrl(avatarUrl!)
        : '';
    final scheme = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: 18,
      backgroundColor: scheme.surfaceContainerHighest,
      backgroundImage: resolved.isNotEmpty ? NetworkImage(resolved) : null,
      child: resolved.isNotEmpty
          ? null
          : HugeIcon(
              icon: HugeIcons.strokeRoundedUser,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
    );
  }
}

// ============================================================================
// 封面大图组件
// ============================================================================
