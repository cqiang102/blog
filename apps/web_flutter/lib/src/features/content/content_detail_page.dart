// 内容详情页模块
// 支持 Markdown 渲染、视频播放、点赞、评论列表和浏览记录
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';
import '../../core/auth_controller.dart';
import '../../core/constants.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      _recordViewOnce(auth.accessToken);
    });
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
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('内容详情')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm + 4),
              FilledButton.icon(
                onPressed: () =>
                    ref.invalidate(contentDetailProvider(widget.id)),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      data: (content) {
        final comments = ref.watch(commentsProvider(widget.id));
        final auth = ref.watch(authControllerProvider);
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
          expandedHeight: kSliverAppBarExpandedHeight,
          pinned: true,
          title: Text(content.title),
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
              Text(
                content.summary,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 内容查看器
              _ContentViewer(content: content),
              const SizedBox(height: AppSpacing.xl),

              // 操作按钮
              _buildActions(context, content),
              const SizedBox(height: AppSpacing.lg),

              // 评论输入
              _buildCommentInput(context, auth),
              const SizedBox(height: AppSpacing.sm + 4),

              // 评论标题
              Text('评论', style: Theme.of(context).textTheme.titleLarge),
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
        const SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.xl),
        ),
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

  /// 构建操作按钮
  Widget _buildActions(BuildContext context, BlogContent content) {
    return Row(
      children: [
        _LikeButton(contentId: widget.id, content: content),
        const SizedBox(width: AppSpacing.sm + 4),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.mode_comment_outlined),
          label: Text('评论 ${content.commentCount}'),
        ),
      ],
    );
  }

  /// 构建评论输入
  Widget _buildCommentInput(BuildContext context, AuthController auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _commentController,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: auth.isAuthenticated ? '写下你的评论' : '登录后发表评论',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submitComment,
            icon: const Icon(Icons.send),
            label: const Text('发布评论'),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text('暂无评论'),
      );
    }

    final auth = ref.watch(authControllerProvider);

    return SliverList.builder(
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Card(
          key: ValueKey(comment.id),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(comment.authorNickname),
            subtitle: comment.blocked
                ? Row(
                    children: [
                      Icon(Icons.block, size: 14, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '评论审核中，暂不可见',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(comment.body),
            trailing:
                auth.isAuthenticated && auth.user?.id == comment.authorId
                    ? IconButton(
                        tooltip: '删除评论',
                        onPressed: () =>
                            _deleteComment(context, ref, comment),
                        icon:
                            Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                      )
                    : null,
          ),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
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
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.article_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: content.coverUrl,
      fit: BoxFit.cover,
      memCacheWidth: 1200,
      placeholder: (context, url) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (context, url, error) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.broken_image,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
              ),
            ),
          ),
        ),
      ContentType.image => _ImageGallery(urls: content.mediaUrls),
      ContentType.video => _VideoPlayerWidget(content: content),
    };
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
        final columns = constraints.maxWidth >= kWideBreakpoint
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
          itemBuilder: (context, index) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: urls[index],
              fit: BoxFit.cover,
              memCacheWidth: 800,
              placeholder: (context, url) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (context, url, error) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.broken_image)),
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
    final videoUrl = widget.content.mediaUrls.isNotEmpty
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
                  placeholder: (context, url) => ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
        child: controller.value.isPlaying
            ? const SizedBox.shrink()
            : const ColoredBox(
                color: AppColors.overlayDark,
                child: Center(
                  child: Icon(
                    Icons.play_arrow,
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
        oldWidget.content.likedByCurrentUser != widget.content.likedByCurrentUser ||
        oldWidget.content.likeCount != widget.content.likeCount) {
      _optimisticLiked = widget.content.likedByCurrentUser;
      _optimisticLikeCount = widget.content.likeCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _liking ? null : _toggleLike,
      icon: Icon(
        _optimisticLiked ? Icons.favorite : Icons.favorite_outline,
      ),
      label: Text('点赞 $_optimisticLikeCount'),
    );
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      // 失败回滚
      if (!mounted) return;
      setState(() {
        _optimisticLiked = previousLiked;
        _optimisticLikeCount = previousCount;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }
}
