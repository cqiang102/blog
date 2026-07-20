import 'package:intl/intl.dart';

import '../../../core/models.dart';

String formatAdminDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return '未发布';
  return DateFormat('yyyy-MM-dd HH:mm').format(date);
}

String formatAdminBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}

int? parseNullableInt(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

MediaAssetType inferMediaType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mov')) {
    return MediaAssetType.video;
  }
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp')) {
    return MediaAssetType.image;
  }
  return MediaAssetType.file;
}
