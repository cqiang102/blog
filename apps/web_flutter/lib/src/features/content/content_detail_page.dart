// 内容详情页模块
// 支持 Markdown 渲染、视频播放、点赞、评论列表和浏览记录
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';
import '../../core/models.dart';

/// 内容详情页 Widget
/// 展示完整内容、支持点赞/取消点赞、提交评论和查看评论列表
class ContentDetailPage extends ConsumerStatefulWidget {
  const ContentDetailPage({required this.id, super.key});

  final String id; // 内容 ID

  @override
  ConsumerState<ContentDetailPage> createState() => _ContentDetailPageState();
}

/// 内容详情页状态管理
/// 管理评论输入、浏览记录和视频播放
class _ContentDetailPageState extends ConsumerState<ContentDetailPage> {
  final _commentController = TextEditingController(); // 评论输入框控制器
  bool _viewRecorded = false; // 是否已记录浏览（防止重复记录）
  bool _submitting = false; // 是否正在提交评论

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentDetailProvider(widget.id));
    final comments = ref.watch(commentsProvider(widget.id));
    final auth = ref.watch(authControllerProvider);

    return content.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, stackTrace) => Scaffold(
            appBar: AppBar(title: const Text('内容详情')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        () => ref.invalidate(contentDetailProvider(widget.id)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
      data: (content) {
        _recordViewOnce(auth.accessToken);
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              title: Text(content.title),
              flexibleSpace: FlexibleSpaceBar(
                background: _HeroCover(content: content),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList.list(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(content.type.label)),
                      for (final tag in content.tags) Chip(label: Text(tag)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    content.summary,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  _ContentViewer(content: content),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      _LikeButton(contentId: widget.id, content: content),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.mode_comment_outlined),
                        label: Text('评论 ${content.commentCount}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _commentController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: auth.isAuthenticated ? '写下你的评论' : '登录后发表评论',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submitComment,
                      icon: const Icon(Icons.send),
                      label: const Text('发布评论'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('评论', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  comments.when(
                    loading:
                        () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    error: (error, stackTrace) => Text(error.toString()),
                    data: (page) => _CommentList(comments: page.items, contentId: widget.id),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 记录浏览次数（仅首次）
  /// 首次查看详情时调用 API 记录浏览，失败不阻断阅读
  void _recordViewOnce(String? accessToken) {
    if (_viewRecorded) return;
    _viewRecorded = true;
    Future.microtask(() async {
      try {
        await ref
            .read(apiClientProvider)
            .recordView(contentId: widget.id, accessToken: accessToken);
        if (mounted) {
          ref.invalidate(contentDetailProvider(widget.id));
        }
      } catch (_) {
        // 浏览记录失败不阻断阅读。
      }
    });
  }

  /// 提交评论
  /// 未登录时跳转登录页，已登录则提交评论并刷新评论列表
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
      ref.invalidate(commentsProvider(widget.id));
      ref.invalidate(contentDetailProvider(widget.id));
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

/// 评论列表组件
/// 展示评论列表，支持删除自己的评论，被屏蔽评论显示审核提示
class _CommentList extends ConsumerWidget {
  const _CommentList({required this.comments, required this.contentId});

  final List<CommentItem> comments; // 评论列表
  final String contentId; // 内容 ID（用于刷新评论数据）

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('暂无评论'),
      );
    }

    final auth = ref.watch(authControllerProvider);

    return Column(
      children: [
        for (final comment in comments)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(comment.authorNickname),
              subtitle: comment.blocked
                  ? Row(
                      children: [
                        const Icon(Icons.block, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '评论审核中，暂不可见',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(comment.body),
              trailing: auth.isAuthenticated && auth.user?.id == comment.authorId
                  ? IconButton(
                      tooltip: '删除评论',
                      onPressed: () => _deleteComment(context, ref, comment),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  /// 删除评论
  /// 调用 API 删除评论后刷新评论列表
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
}

/// 封面大图组件
/// 详情页顶部的 Hero 封面图，无封面时显示占位图标
class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.content});

  final BlogContent content; // 内容数据

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
    return Image.network(content.coverUrl, fit: BoxFit.cover);
  }
}

/// 内容查看器组件
/// 根据内容类型（文本/图文/图片/视频）渲染不同的展示方式
class _ContentViewer extends StatelessWidget {
  const _ContentViewer({required this.content});

  final BlogContent content; // 内容数据

  @override
  Widget build(BuildContext context) {
    return switch (content.type) {
      ContentType.text || ContentType.article => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: MarkdownBody(
            data: content.markdown.isEmpty ? content.summary : content.markdown,
            selectable: true,
          ),
        ),
      ),
      ContentType.image => _ImageGallery(urls: content.mediaUrls),
      ContentType.video => _VideoPlayerWidget(content: content),
    };
  }
}

/// 图片画廊组件
/// 响应式网格展示多张图片，支持 1-3 列自适应
class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.urls});

  final List<String> urls; // 图片 URL 列表

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return const _MediaEmpty(label: '暂无图片');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: urls.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder:
              (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(urls[index], fit: BoxFit.cover),
              ),
        );
      },
    );
  }
}

/// 视频播放器组件
/// 管理视频控制器的生命周期，支持播放/暂停和进度拖拽
class _VideoPlayerWidget extends StatefulWidget {
  const _VideoPlayerWidget({required this.content});

  final BlogContent content; // 内容数据（包含视频 URL）

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

/// 视频播放器状态管理
/// 负责初始化视频控制器、监听播放状态和资源释放
class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller; // 视频播放控制器
  bool _isInitialized = false; // 视频是否已初始化完成
  bool _hasError = false; // 视频加载是否出错

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  /// 初始化视频播放器
  /// 解析视频 URL，创建控制器并完成初始化
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
      _controller!.addListener(() {
        if (mounted) setState(() {});
      });
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
      return _MediaEmpty(label: '视频加载失败');
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
                Image.network(widget.content.coverUrl, fit: BoxFit.cover),
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

/// 视频控制覆盖层
/// 点击切换播放/暂停状态，暂停时显示播放按钮
class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({required this.controller});

  final VideoPlayerController controller; // 视频播放控制器

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
        duration: const Duration(milliseconds: 300),
        child: controller.value.isPlaying
            ? const SizedBox.shrink()
            : Container(
                color: Colors.black26,
                child: const Center(
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
      ),
    );
  }
}

/// 媒体空状态组件
/// 图片/视频加载失败或为空时显示的占位界面
class _MediaEmpty extends StatelessWidget {
  const _MediaEmpty({required this.label});

  final String label; // 提示文本

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

/// 点赞按钮组件
/// 独立管理点赞状态，避免点赞操作导致整个页面重建
class _LikeButton extends ConsumerStatefulWidget {
  const _LikeButton({required this.contentId, required this.content});

  final String contentId;
  final BlogContent content;

  @override
  ConsumerState<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<_LikeButton> {
  bool _liking = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _liking ? null : _toggleLike,
      icon: Icon(
        widget.content.likedByCurrentUser
            ? Icons.favorite
            : Icons.favorite_outline,
      ),
      label: Text('点赞 ${widget.content.likeCount}'),
    );
  }

  Future<void> _toggleLike() async {
    final auth = ref.read(authControllerProvider);
    final token = auth.accessToken;
    if (token == null) {
      context.go('/login?from=/contents/${widget.contentId}');
      return;
    }

    setState(() => _liking = true);
    try {
      if (widget.content.likedByCurrentUser) {
        await ref
            .read(apiClientProvider)
            .unlikeContent(accessToken: token, contentId: widget.contentId);
      } else {
        await ref
            .read(apiClientProvider)
            .likeContent(accessToken: token, contentId: widget.contentId);
      }
      ref.invalidate(contentDetailProvider(widget.contentId));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }
}
