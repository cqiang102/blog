import 'package:flutter/material.dart';

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
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Icon(Icons.broken_image)),
                      ),
                      if (isCover)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Icon(Icons.check, color: Colors.white, size: 32),
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
