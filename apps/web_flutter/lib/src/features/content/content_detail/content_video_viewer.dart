part of '../content_detail_page.dart';

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
  int _initializationGeneration = 0;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant _VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_videoUrl(oldWidget.content) != _videoUrl(widget.content)) {
      _initPlayer();
    }
  }

  String _videoUrl(BlogContent content) {
    if (content.mediaUrls.isEmpty) return '';
    return resolveMediaUrl(content.mediaUrls.first);
  }

  Future<void> _initPlayer() async {
    final generation = ++_initializationGeneration;
    final previousController = _controller;
    _controller = null;
    _isInitialized = false;
    _hasError = false;
    await previousController?.dispose();

    if (!mounted || generation != _initializationGeneration) return;

    final videoUrl = _videoUrl(widget.content);
    final uri = Uri.tryParse(videoUrl);
    if (uri == null || !uri.hasScheme) {
      setState(() => _hasError = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    try {
      await controller.initialize();
      if (!mounted || generation != _initializationGeneration) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted || generation != _initializationGeneration) return;
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _initializationGeneration += 1;
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
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return GestureDetector(
          onTap: () {
            if (value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
          },
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, AppAnimations.normal),
            child: value.isPlaying
                ? const SizedBox.expand(key: ValueKey('playing'))
                : const ColoredBox(
                    key: ValueKey('paused'),
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
      },
    );
  }
}
