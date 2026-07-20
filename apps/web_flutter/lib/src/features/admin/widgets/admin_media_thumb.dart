import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/media_url.dart';
import '../../../core/models.dart';

class AdminMediaThumb extends StatelessWidget {
  const AdminMediaThumb({
    super.key,
    required this.url,
    required this.type,
    required this.size,
  });

  final String url;
  final MediaAssetType type;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final fallbackIcon = switch (type) {
      MediaAssetType.video => HugeIcons.strokeRoundedPlayCircle,
      MediaAssetType.file => HugeIcons.strokeRoundedFile01,
      MediaAssetType.image => HugeIcons.strokeRoundedImage01,
    };
    final placeholder = SizedBox(
      width: size.width,
      height: size.height,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: HugeIcon(icon: fallbackIcon),
      ),
    );

    if (url.isEmpty || type != MediaAssetType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: placeholder,
      );
    }

    final resolvedUrl = resolveMediaUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: kIsWeb
          ? Image.network(
              resolvedUrl,
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => placeholder,
            )
          : CachedNetworkImage(
              imageUrl: resolvedUrl,
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
              memCacheWidth: size.width.toInt() * 2,
              errorWidget: (context, url, error) => placeholder,
            ),
    );
  }
}
