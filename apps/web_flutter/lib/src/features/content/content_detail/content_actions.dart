part of '../content_detail_page.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final countText = _optimisticLikeCount > 99
        ? '99+'
        : '$_optimisticLikeCount';
    final icon = Icon(
      _optimisticLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      size: 18,
    );
    final onPressed = _liking ? null : _toggleLike;

    final button = _optimisticLiked
        ? FilledButton.icon(
            key: const ValueKey('liked'),
            onPressed: onPressed,
            icon: icon,
            label: Text(countText),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              disabledBackgroundColor: scheme.primary.withValues(alpha: 0.36),
              disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.72),
            ),
          )
        : OutlinedButton.icon(
            key: const ValueKey('not-liked'),
            onPressed: onPressed,
            icon: icon,
            label: Text(countText),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              foregroundColor: scheme.onSurfaceVariant,
              backgroundColor: scheme.surfaceContainerLow,
              side: BorderSide(color: scheme.outlineVariant),
            ),
          );

    return Tooltip(
      message: _optimisticLiked ? '已点赞，点击取消' : '点赞',
      child: AnimatedSwitcher(
        duration: AppMotion.duration(context, AppAnimations.fast),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: button,
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
      ).showSnackBar(SnackBar(content: Text(userFacingErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }
}
