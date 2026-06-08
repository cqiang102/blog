import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/models.dart';
import '../../../../core/theme.dart';

/// 媒体资源区域
/// 显示已上传的媒体文件，支持删除和设置封面
class MediaSection extends StatelessWidget {
  const MediaSection({
    super.key,
    required this.type,
    required this.mediaUrls,
    this.coverUrl,
    required this.isUploading,
    required this.onUpload,
    required this.onRemove,
    required this.onSetCover,
  });

  final ContentType type;
  final List<String> mediaUrls;
  final String? coverUrl;
  final bool isUploading;
  final VoidCallback onUpload;
  final void Function(int index) onRemove;
  final void Function(String url) onSetCover;

  bool get isImage => type == ContentType.image;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        const SizedBox(height: 8),
        if (mediaUrls.isEmpty)
          _buildEmptyState(context)
        else
          _buildMediaGrid(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            isImage ? '图片资源' : '视频资源',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        FilledButton.icon(
          onPressed: isUploading ? null : onUpload,
          icon: isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file),
          label: Text(isUploading ? '上传中...' : '上传文件'),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              isImage ? Icons.image_outlined : Icons.videocam_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              isImage ? '暂无图片，请上传' : '暂无视频，请上传',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = isImage
            ? (constraints.maxWidth < 400 ? 120.0 : 150.0)
            : (constraints.maxWidth < 400 ? 160.0 : 200.0);
        final cardHeight = isImage ? cardWidth : cardWidth * 0.56;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(mediaUrls.length, (index) {
            final url = mediaUrls[index];
            final isCover = url == coverUrl;
            return SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: _MediaCard(
                url: url,
                isImage: isImage,
                isCover: isCover,
                onSetCover: () => onSetCover(url),
                onRemove: () => onRemove(index),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.url,
    required this.isImage,
    required this.isCover,
    required this.onSetCover,
    required this.onRemove,
  });

  final String url;
  final bool isImage;
  final bool isCover;
  final VoidCallback onSetCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildContent(context),
          if (isCover) _buildCoverBadge(context),
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isImage) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, size: 32),
              const SizedBox(height: 4),
              Text(
                '加载失败',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        fadeInDuration: const Duration(milliseconds: 200),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.videocam, size: 48),
      ),
    );
  }

  Widget _buildCoverBadge(BuildContext context) {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '封面',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.overlayDark,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCover)
              IconButton(
                icon: const Icon(Icons.image, color: AppColors.onOverlay, size: 20),
                tooltip: '设为封面',
                onPressed: onSetCover,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: EdgeInsets.zero,
              ),
            IconButton(
              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error, size: 20),
              tooltip: '删除',
              onPressed: onRemove,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
