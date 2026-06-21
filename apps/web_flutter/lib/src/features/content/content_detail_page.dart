// 内容详情页模块
// 支持 Markdown 渲染、视频播放、点赞、评论列表和浏览记录
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../state/state.dart';
import '../../widgets/widgets.dart';
import '../../auth/auth_controller.dart';

import '../../core/media_url.dart';
import '../../core/models.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_colors.dart';

part 'content_detail/content_error_scaffold.dart';
part 'content_detail/content_comments.dart';
part 'content_detail/content_media_viewers.dart';
part 'content_detail/content_actions.dart';

/// 内容详情页 Widget
class ContentDetailPage extends ConsumerStatefulWidget {
  const ContentDetailPage({required this.id, super.key});

  final String id;

  @override
  ConsumerState<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends ConsumerState<ContentDetailPage> {
  final _commentController = TextEditingController();
  bool _viewRecorded = false;
  bool _submitting = false;

  @override
  void didUpdateWidget(covariant ContentDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _viewRecorded = false;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentDetailProvider(widget.id));

    return content.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => _ContentErrorScaffold(
        error: error,
        onRetry: () => ref.invalidate(contentDetailProvider(widget.id)),
      ),
      data: (content) {
        final comments = ref.watch(commentsProvider(widget.id));
        final auth = ref.watch(authControllerProvider);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _recordViewOnce(auth.accessToken);
        });
        return _buildContent(context, content, comments, auth);
      },
    );
  }

  /// 构建内容主体
  Widget _buildContent(
    BuildContext context,
    BlogContent content,
    AsyncValue<PageResult<CommentItem>> comments,
    AuthController auth,
  ) {
    return CustomScrollView(
      slivers: [
        // AppBar
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          title: Text(content.title),
          actions: const [
            AppThemeToggle(),
            SizedBox(width: AppSpacing.sm),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _HeroCover(content: content),
          ),
        ),

        // 内容区域
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList.list(
            children: [
              // 标签
              _buildTags(context, content),
              const SizedBox(height: AppSpacing.md),

              // 摘要
              if (content.summary.isNotEmpty) ...[
                Text(
                  content.summary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // 内容查看器
              _ContentViewer(content: content),
              const SizedBox(height: AppSpacing.xl),

              // 评论输入
              _buildCommentInput(context, content),
              const SizedBox(height: AppSpacing.md),

              // 评论标题
              Row(
                children: [
                  Text('评论', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    '共${(comments.value?.total ?? content.commentCount) > 99 ? '99+' : comments.value?.total ?? content.commentCount}条',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 4),
            ],
          ),
        ),

        // 评论列表（使用 SliverList 优化性能）
        comments.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stackTrace) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(error.toString()),
            ),
          ),
          data: (page) => SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: _CommentList(comments: page.items, contentId: widget.id),
          ),
        ),

        // 底部间距
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }

  /// 构建标签
  Widget _buildTags(BuildContext context, BlogContent content) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        Chip(label: Text(content.type.label)),
        for (final tag in content.tags) Chip(label: Text(tag)),
      ],
    );
  }

  /// 构建评论输入（含点赞和发布按钮）
  Widget _buildCommentInput(BuildContext context, BlogContent content) {
    final auth = ref.read(authControllerProvider);
    return Stack(
      children: [
        TextField(
          controller: _commentController,
          minLines: 1,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: auth.isAuthenticated ? '写下你的评论' : '登录后发表评论',
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LikeButton(contentId: widget.id, content: content),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _submitting ? null : _submitComment,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSent,
                  size: 18,
                ),
                label: const Text('发布'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 记录浏览次数（仅首次，不触发详情刷新）
  void _recordViewOnce(String? accessToken) {
    if (_viewRecorded) return;
    _viewRecorded = true;
    Future.microtask(() async {
      try {
        await ref
            .read(apiClientProvider)
            .recordView(contentId: widget.id, accessToken: accessToken);
        // 浏览记录是 fire-and-forget，不需要 invalidate 详情
        // viewCount 可以在下次进入页面时获取
      } catch (_) {
        // 浏览记录失败不阻断阅读。
      }
    });
  }

  /// 提交评论
  Future<void> _submitComment() async {
    final auth = ref.read(authControllerProvider);
    final token = auth.accessToken;
    if (token == null) {
      context.go('/login?from=/contents/${widget.id}');
      return;
    }
    final body = _commentController.text.trim();
    if (body.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(apiClientProvider)
          .createComment(accessToken: token, contentId: widget.id, body: body);
      _commentController.clear();
      // 只刷新评论列表，不刷新详情（评论数会在下次进入时更新）
      ref.invalidate(commentsProvider(widget.id));
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
