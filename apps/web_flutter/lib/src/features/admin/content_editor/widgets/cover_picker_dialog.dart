import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/media_url.dart';
import '../../../../core/theme.dart';

/// 封面图选择器对话框
class CoverPickerDialog extends StatelessWidget {
  const CoverPickerDialog({
    super.key,
    required this.mediaUrls,
    this.currentCoverUrl,
  });

  final List<String> mediaUrls;
  final String? currentCoverUrl;

  /// 显示封面选择器对话框
  static Future<String?> show(
    BuildContext context, {
    required List<String> mediaUrls,
    String? currentCoverUrl,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => CoverPickerDialog(
        mediaUrls: mediaUrls,
        currentCoverUrl: currentCoverUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择封面图'),
      content: SizedBox(
        width: 400,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(mediaUrls.length, (index) {
            final url = mediaUrls[index];
            final isCover = url == currentCoverUrl;
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(url),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: resolveMediaUrl(url),
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            Center(child: HugeIcon(icon: HugeIcons.strokeRoundedImageNotFound01)),
                      ),
                      if (isCover)
                        const ColoredBox(
                          color: AppColors.overlayDark,
                          child: Center(
                            child: HugeIcon(icon: HugeIcons.strokeRoundedTick01, color: AppColors.onOverlay, size: 32),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(''), // 空字符串表示清除封面
          child: const Text('清除封面'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
