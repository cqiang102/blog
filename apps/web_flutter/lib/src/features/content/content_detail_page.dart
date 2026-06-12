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
import '../../core/api_providers.dart';
import '../../core/app_ui.dart';
import '../../core/auth_controller.dart';
import '../../core/constants.dart';
import '../../core/media_url.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

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
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, stackTrace) => _ContentErrorScaffold(
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
          actions: const [AppThemeToggle(), SizedBox(width: AppSpacing.sm)],
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
          loading:
              () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          error:
              (error, stackTrace) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(error.toString()),
                ),
              ),
          data:
              (page) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: _CommentList(
                  comments: page.items,
                  contentId: widget.id,
                ),
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
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedSent, size: 18),
                label: const Text('发布'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

class _ContentErrorScaffold extends StatelessWidget {
  const _ContentErrorScaffold({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final notFound =
        error is ApiException && (error as ApiException).statusCode == 404;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('内容详情'),
        actions: const [AppThemeToggle(), SizedBox(width: AppSpacing.sm)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: notFound
                            ? HugeIcons.strokeRoundedFileNotFound
                            : HugeIcons.strokeRoundedCloudOff,
                        size: 36,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      notFound ? '这篇内容已不可用' : '内容加载失败',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      notFound ? '内容可能已归档、删除，或当前链接已经失效。' : error.toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: () => context.go('/contents'),
                          child: const Text('返回全部内容'),
                        ),
                        OutlinedButton(
                          onPressed: onRetry,
                          child: const Text('重新检查'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 评论列表组件（使用 SliverList 优化性能）
// ============================================================================

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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              _formatTime(comment.createdAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
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
                                    color:
                                        Theme.of(context).colorScheme.error,
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
    final resolved =
        avatarUrl != null && avatarUrl!.isNotEmpty ? resolveMediaUrl(avatarUrl!) : '';
    final scheme = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: 18,
      backgroundColor: scheme.surfaceContainerHighest,
      backgroundImage: resolved.isNotEmpty ? NetworkImage(resolved) : null,
      child: resolved.isNotEmpty
          ? null
          : HugeIcon(icon: HugeIcons.strokeRoundedUser, size: 20, color: scheme.onSurfaceVariant),
    );
  }
}

// ============================================================================
// 封面大图组件
// ============================================================================

class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    if (content.coverUrl.isEmpty) {
      return const _HeroPlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: resolveMediaUrl(content.coverUrl),
      fit: BoxFit.cover,
      memCacheWidth: 1200,
      placeholder: (context, url) => const _HeroPlaceholder(),
      errorWidget: (context, url, error) => const _HeroPlaceholder(),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
        ),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedBook01,
          size: 56,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

// ============================================================================
// 内容查看器组件
// ============================================================================

class _ContentViewer extends StatelessWidget {
  const _ContentViewer({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    return switch (content.type) {
      ContentType.markdown => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + 4),
          child: SelectionArea(
            child: MarkdownBody(
              data:
                  content.markdown.isEmpty ? content.summary : content.markdown,
              softLineBreak: true,
              imageBuilder: _buildMarkdownImage,
            ),
          ),
        ),
      ),
      ContentType.image => _ImageGallery(urls: content.mediaUrls),
      ContentType.video => _VideoPlayerWidget(content: content),
    };
  }

  Widget _buildMarkdownImage(Uri uri, String? title, String? alt) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: resolveMediaUrl(uri.toString()),
        fit: BoxFit.contain,
        placeholder:
            (context, url) => Container(
              constraints: const BoxConstraints(minHeight: 180),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
        errorWidget:
            (context, url, error) => Container(
              constraints: const BoxConstraints(minHeight: 180),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HugeIcon(icon: HugeIcons.strokeRoundedImageNotFound01, size: 40),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '图片暂时无法加载',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

// ============================================================================
// 图片画廊组件（添加 placeholder 优化体验）
// ============================================================================

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return const _MediaEmpty(label: '暂无图片');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= kWideBreakpoint
                ? 3
                : constraints.maxWidth >= kSmallTabletBreakpoint
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: urls.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.sm + 4,
            mainAxisSpacing: AppSpacing.sm + 4,
          ),
          itemBuilder:
              (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: urls[index],
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  placeholder:
                      (context, url) => ColoredBox(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      ),
                  errorWidget:
                      (context, url, error) => ColoredBox(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        child: const Center(child: HugeIcon(icon: HugeIcons.strokeRoundedImageNotFound01)),
                      ),
                ),
              ),
        );
      },
    );
  }
}

// ============================================================================
// 视频播放器组件（使用 ValueListenableBuilder 优化重建）
// ============================================================================

class _VideoPlayerWidget extends StatefulWidget {
  const _VideoPlayerWidget({required this.content});

  final BlogContent content;

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final videoUrl =
        widget.content.mediaUrls.isNotEmpty
            ? widget.content.mediaUrls.first
            : '';
    if (videoUrl.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _controller!.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const _MediaEmpty(label: '视频加载失败');
    }

    if (!_isInitialized || _controller == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.content.coverUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: widget.content.coverUrl,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => ColoredBox(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      ),
                ),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_controller!),
            _ControlsOverlay(controller: _controller!),
            VideoProgressIndicator(_controller!, allowScrubbing: true),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 视频控制覆盖层
// ============================================================================

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: AnimatedSwitcher(
        duration: AppAnimations.normal,
        child:
            controller.value.isPlaying
                ? const SizedBox.shrink()
                : const ColoredBox(
                  color: AppColors.overlayDark,
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedPlay,
                      color: AppColors.onOverlay,
                      size: 64,
                    ),
                  ),
                ),
      ),
    );
  }
}

// ============================================================================
// 媒体空状态组件
// ============================================================================

class _MediaEmpty extends StatelessWidget {
  const _MediaEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(label)),
      ),
    );
  }
}

// ============================================================================
// 点赞按钮组件（使用乐观更新优化体验）
// ============================================================================

class _LikeButton extends ConsumerStatefulWidget {
  const _LikeButton({required this.contentId, required this.content});

  final String contentId;
  final BlogContent content;

  @override
  ConsumerState<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<_LikeButton> {
  bool _liking = false;
  // 乐观更新状态
  late bool _optimisticLiked;
  late int _optimisticLikeCount;

  @override
  void initState() {
    super.initState();
    _optimisticLiked = widget.content.likedByCurrentUser;
    _optimisticLikeCount = widget.content.likeCount;
  }

  @override
  void didUpdateWidget(_LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content.id != widget.content.id ||
        oldWidget.content.likedByCurrentUser !=
            widget.content.likedByCurrentUser ||
        oldWidget.content.likeCount != widget.content.likeCount) {
      _optimisticLiked = widget.content.likedByCurrentUser;
      _optimisticLikeCount = widget.content.likeCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: ValueKey(_optimisticLiked),
      onPressed: _liking ? null : _toggleLike,
      icon: HugeIcon(icon: _optimisticLiked ? HugeIcons.strokeRoundedFavourite : HugeIcons.strokeRoundedFavourite, size: 18),
      label: Text(_optimisticLikeCount > 99 ? '99+' : '$_optimisticLikeCount'),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ).scalePulse();
  }

  Future<void> _toggleLike() async {
    final auth = ref.read(authControllerProvider);
    final token = auth.accessToken;
    if (token == null) {
      context.go('/login?from=/contents/${widget.contentId}');
      return;
    }

    // 乐观更新：立即更新 UI
    final previousLiked = _optimisticLiked;
    final previousCount = _optimisticLikeCount;
    setState(() {
      _liking = true;
      _optimisticLiked = !_optimisticLiked;
      _optimisticLikeCount += _optimisticLiked ? 1 : -1;
    });

    try {
      if (previousLiked) {
        await ref
            .read(apiClientProvider)
            .unlikeContent(accessToken: token, contentId: widget.contentId);
      } else {
        await ref
            .read(apiClientProvider)
            .likeContent(accessToken: token, contentId: widget.contentId);
      }
      // 成功后刷新详情（后台更新，不阻塞 UI）
      ref.invalidate(contentDetailProvider(widget.contentId));
    } on ApiException catch (error) {
      // 失败回滚
      if (!mounted) return;
      setState(() {
        _optimisticLiked = previousLiked;
        _optimisticLikeCount = previousCount;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      // 失败回滚
      if (!mounted) return;
      setState(() {
        _optimisticLiked = previousLiked;
        _optimisticLikeCount = previousCount;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }
}
