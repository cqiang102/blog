part of '../content_detail_page.dart';

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
              data: content.markdown.isEmpty
                  ? content.summary
                  : content.markdown,
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
        placeholder: (context, url) => Container(
          constraints: const BoxConstraints(minHeight: 180),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => Container(
          constraints: const BoxConstraints(minHeight: 180),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedImageNotFound01,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('图片暂时无法加载', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 图片画廊组件（大图 + 缩略图预览 + 左右切换）
// ============================================================================

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.urls});

  final List<String> urls;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return const _MediaEmpty(label: '暂无图片');
    }

    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 大图区域
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.urls.length,
                  onPageChanged: (index) =>
                      setState(() => _currentIndex = index),
                  itemBuilder: (context, index) {
                    final resolvedUrl = resolveMediaUrl(widget.urls[index]);
                    return InteractiveViewer(
                      maxScale: 4,
                      child: CachedNetworkImage(
                        imageUrl: resolvedUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: 1600,
                        placeholder: (context, url) =>
                            ColoredBox(color: scheme.surfaceContainerHighest),
                        errorWidget: (context, url, error) => ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: const Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedImageNotFound01,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // 左箭头
            if (widget.urls.length > 1)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _NavArrow(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    onTap: _currentIndex > 0
                        ? () => _pageController.previousPage(
                            duration: AppAnimations.normal,
                            curve: Curves.easeOutCubic,
                          )
                        : null,
                  ),
                ),
              ),
            // 右箭头
            if (widget.urls.length > 1)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _NavArrow(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    onTap: _currentIndex < widget.urls.length - 1
                        ? () => _pageController.nextPage(
                            duration: AppAnimations.normal,
                            curve: Curves.easeOutCubic,
                          )
                        : null,
                  ),
                ),
              ),
            // 页码指示器
            if (widget.urls.length > 1)
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.urls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // 缩略图条
        if (widget.urls.length > 1) ...[
          const SizedBox(height: AppSpacing.sm + 4),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.urls.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final isSelected = index == _currentIndex;
                final resolvedUrl = resolveMediaUrl(widget.urls[index]);
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: AppAnimations.normal,
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child:
                      AnimatedContainer(
                            duration: AppAnimations.fast,
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? scheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: resolvedUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                memCacheWidth: 128,
                                placeholder: (context, url) => ColoredBox(
                                  color: scheme.surfaceContainerHighest,
                                ),
                                errorWidget: (context, url, error) =>
                                    ColoredBox(
                                      color: scheme.surfaceContainerHighest,
                                      child: const Center(
                                        child: HugeIcon(
                                          icon: HugeIcons
                                              .strokeRoundedImageNotFound01,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          )
                          .animate(target: isSelected ? 1 : 0)
                          .scale(
                            begin: const Offset(0.95, 0.95),
                            end: const Offset(1, 1),
                            duration: 200.ms,
                            curve: Curves.easeOutCubic,
                          ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// 导航箭头按钮
class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, this.onTap});

  final List<List<dynamic>> icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: HugeIcon(icon: icon, color: Colors.white, size: 20),
          ),
        ),
      ),
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
                  imageUrl: resolveMediaUrl(widget.content.coverUrl),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => ColoredBox(
                    color: Theme.of(
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
        child: controller.value.isPlaying
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
