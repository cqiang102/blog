part of '../content_detail_page.dart';

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
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final isSelected = index == _currentIndex;
                final resolvedUrl = resolveMediaUrl(widget.urls[index]);
                return GestureDetector(
                  onTap: () {
                    if (AppMotion.reduce(context)) {
                      _pageController.jumpToPage(index);
                    } else {
                      _pageController.animateToPage(
                        index,
                        duration: AppAnimations.normal,
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child:
                      AnimatedContainer(
                            duration: AppMotion.duration(
                              context,
                              AppAnimations.fast,
                            ),
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
