import 'api/api_client_base.dart';

/// 构建可长期保存在 Markdown 中的媒体引用。
String mediaFileReference(String mediaId) =>
    '/api/v1/media-assets/$mediaId/file';

/// 将后端相对媒体引用解析为当前 API 服务的绝对 URL。
String resolveMediaUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.hasScheme || !uri.path.startsWith('/api/')) {
    return trimmed;
  }

  final apiUri = Uri.parse(apiBaseUrl);
  return apiUri
      .replace(path: uri.path, query: uri.hasQuery ? uri.query : null)
      .toString();
}
