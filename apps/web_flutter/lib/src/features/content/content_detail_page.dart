// 内容详情页模块
// 支持 Markdown 渲染、视频播放、点赞、评论列表和浏览记录
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/api_client.dart';
import '../../state/state.dart';
import '../../widgets/widgets.dart';
import '../../auth/auth_controller.dart';

import '../../core/constants.dart';
import '../../core/markdown_headings.dart';
import '../../core/media_url.dart';
import '../../core/models.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_motion.dart';

part 'content_detail/content_error_scaffold.dart';
part 'content_detail/content_comments.dart';
part 'content_detail/content_article_hero.dart';
part 'content_detail/content_media_viewers.dart';
part 'content_detail/content_markdown_article.dart';
part 'content_detail/content_image_gallery.dart';
part 'content_detail/content_video_viewer.dart';
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
  final _scrollController = ScrollController();
  final _headingKeys = <String, GlobalKey>{};
  bool _viewRecorded = false;
  bool _submitting = false;
  bool _appBarCollapsed = false;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void didUpdateWidget(covariant ContentDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _viewRecorded = false;
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScrollChanged)
      ..dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// SliverAppBar 完全收起后切换为中性表面色，避免整条变成高饱和绿色。
  /// 收起状态由 FlexibleSpaceBarSettings 精确驱动（由 _AppBarCollapseProbe 上报）。
  void _onAppBarCollapsedChanged(bool collapsed) {
    if (!mounted || collapsed == _appBarCollapsed) return;
    setState(() => _appBarCollapsed = collapsed);
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset >= _backToTopScrollThreshold;
    if (show != _showBackToTop && mounted) {
      setState(() => _showBackToTop = show);
    }
  }

  /// 同步目录标题与正文标题的锚点 key 集合。
  List<MarkdownHeading> _syncHeadings(BlogContent content) {
    final source = content.markdown.trim().isEmpty
        ? content.summary
        : content.markdown;
    final headings = extractMarkdownHeadings(source);
    final slugs = {for (final heading in headings) heading.slug};
    _headingKeys.removeWhere((slug, _) => !slugs.contains(slug));
    for (final heading in headings) {
      _headingKeys.putIfAbsent(heading.slug, GlobalKey.new);
    }
    return headings;
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: AppMotion.duration(context, AppAnimations.slow),
      curve: AppAnimations.defaultCurve,
    );
  }

  void _scrollToHeading(MarkdownHeading heading) {
    final headingContext = _headingKeys[heading.slug]?.currentContext;
    if (headingContext == null) return;
    Scrollable.ensureVisible(
      headingContext,
      duration: AppMotion.duration(context, AppAnimations.normal),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
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
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final expandedHeight = viewportWidth >= kDesktopBreakpoint ? 420.0 : 320.0;
    final commentCount = comments.value?.total ?? content.commentCount;
    final scheme = Theme.of(context).colorScheme;
    final collapsed = _appBarCollapsed;
    final appBarForeground = collapsed ? scheme.onSurface : AppColors.onOverlay;
    final headings = _syncHeadings(content);

    return AppPageFrame(
      maxWidth: 1320,
      child: LayoutBuilder(
        builder: (context, frameConstraints) {
          final showToc =
              collapsed &&
              content.type == ContentType.markdown &&
              headings.length > 1 &&
              frameConstraints.maxWidth >= _articleTocMinPageWidth;
          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    expandedHeight: expandedHeight,
                    pinned: true,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    foregroundColor: appBarForeground,
                    backgroundColor: scheme.surface,
                    actions: [
                      AppThemeToggle(color: appBarForeground),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        72,
                        AppSpacing.lg,
                      ),
                      expandedTitleScale: viewportWidth < kSmallTabletBreakpoint
                          ? 1.35
                          : 1.75,
                      title: Text(
                        content.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: appBarForeground,
                          fontWeight: FontWeight.w700,
                          shadows: collapsed
                              ? null
                              : const [
                                  Shadow(
                                    color: Color(0x8A000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                        ),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          _ArticleHero(content: content),
                          _AppBarCollapseProbe(
                            onCollapsedChanged: _onAppBarCollapsedChanged,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppLayout.readingWidth,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ArticleMeta(content: content),
                              const SizedBox(height: AppSpacing.md),
                              _buildTags(context, content),
                              if (content.summary.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.lg),
                                _ArticleSummary(summary: content.summary),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              _ContentViewer(
                                content: content,
                                headingKeys: _headingKeys,
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                              _buildCommentInput(context, content),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                children: [
                                  Text(
                                    '读者评论',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const Spacer(),
                                  Text(
                                    '共${commentCount > 99 ? '99+' : commentCount}条',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  comments.when(
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      ),
                    ),
                    error: (error, stackTrace) => SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppLayout.readingWidth,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(userFacingErrorMessage(error)),
                          ),
                        ),
                      ),
                    ),
                    data: (page) => _CommentList(
                      comments: page.items,
                      contentId: widget.id,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxl),
                  ),
                ],
              ),
              _BackToTopFab(visible: _showBackToTop, onPressed: _scrollToTop),
              if (showToc)
                Positioned(
                  top: kToolbarHeight + AppSpacing.sm,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.xxl,
                  width: _articleTocWidth,
                  child: _ArticleTocPanel(
                    headings: headings,
                    onSelected: _scrollToHeading,
                  ),
                ),
            ],
          );
        },
      ),
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
      if (!mounted) return;
      _commentController.clear();
      // 只刷新评论列表，不刷新详情（评论数会在下次进入时更新）
      ref.invalidate(commentsProvider(widget.id));
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (error) {
      if (!mounted) return;
      _showError(userFacingErrorMessage(error));
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

class _ArticleMeta extends StatelessWidget {
  const _ArticleMeta({required this.content});

  final BlogContent content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final design = AppDesignTokens.of(context);
    final textLength = content.markdown.trim().runes.length;
    final readingMinutes = (textLength / 500).ceil().clamp(1, 99);
    final publishedAt = DateFormat('yyyy年 M月 d日').format(content.publishedAt);

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: design.mint,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            content.type.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _ArticleMetaItem(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedCalendar03),
          label: publishedAt,
        ),
        _ArticleMetaItem(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedClock01),
          label: '约 $readingMinutes 分钟',
        ),
        _ArticleMetaItem(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedView),
          label: '${content.viewCount} 阅读',
        ),
        _ArticleMetaItem(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedComment01),
          label: '${content.commentCount} 评论',
        ),
      ],
    );
  }
}

class _ArticleMetaItem extends StatelessWidget {
  const _ArticleMetaItem({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return IconTheme(
      data: IconThemeData(size: 16, color: color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 16, child: icon),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ArticleSummary extends StatelessWidget {
  const _ArticleSummary({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final design = AppDesignTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: design.mint,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border(left: BorderSide(color: scheme.primary, width: 4)),
      ),
      child: Text(
        summary,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 监听 FlexibleSpaceBar 的收起状态并上报给内容详情页。
///
/// 放在 flexibleSpace 的 background 里，通过继承的 [FlexibleSpaceBarSettings]
/// 精确知道当前是否已完全收起，避免用滚动位移估算产生误差。
class _AppBarCollapseProbe extends StatefulWidget {
  const _AppBarCollapseProbe({required this.onCollapsedChanged});

  final ValueChanged<bool> onCollapsedChanged;

  @override
  State<_AppBarCollapseProbe> createState() => _AppBarCollapseProbeState();
}

class _AppBarCollapseProbeState extends State<_AppBarCollapseProbe> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final collapsed =
        settings != null && settings.currentExtent <= settings.minExtent + 0.5;
    if (collapsed != _collapsed) {
      _collapsed = collapsed;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCollapsedChanged(collapsed);
      });
    }
    return const SizedBox.shrink();
  }
}
