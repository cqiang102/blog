/// 返回可信的站内跳转地址；不合法时回退到 [fallback]。
///
/// 站内地址必须以单个 `/` 开头，且不能包含协议、主机、反斜杠、控制字符
/// 或路径穿越片段。查询参数与片段会原样保留。
String safeInternalRedirect(String? candidate, {String fallback = '/profile'}) {
  if (candidate == null || candidate.isEmpty) return fallback;
  if (candidate.trim() != candidate ||
      !candidate.startsWith('/') ||
      candidate.startsWith('//') ||
      candidate.contains('\\') ||
      candidate.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
    return fallback;
  }

  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return fallback;

  try {
    var pathEnd = candidate.length;
    for (final marker in const ['?', '#']) {
      final index = candidate.indexOf(marker);
      if (index >= 0 && index < pathEnd) pathEnd = index;
    }
    final rawPath = candidate.substring(0, pathEnd);
    final hasUnsafeSegment = rawPath.split('/').any((segment) {
      final decoded = Uri.decodeComponent(segment);
      return decoded == '.' || decoded == '..' || decoded.contains('\\');
    });
    return hasUnsafeSegment ? fallback : candidate;
  } on FormatException {
    return fallback;
  } on ArgumentError {
    return fallback;
  }
}
