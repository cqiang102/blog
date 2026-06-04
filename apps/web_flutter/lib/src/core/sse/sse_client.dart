import 'package:dio/dio.dart';

import 'sse_client_stub.dart'
    if (dart.library.html) 'sse_client_web.dart'
    if (dart.library.io) 'sse_client_io.dart' as impl;
import 'sse_event.dart';

/// 按平台选择 SSE POST 实现
///
/// Web 端使用 XMLHttpRequest 实现增量读取
/// IO 端使用 Dio 的 ResponseType.stream
Future<List<SseEvent>> postSse({
  required Dio dio,
  required String path,
  required Map<String, dynamic> body,
  required String accessToken,
  required void Function(SseEvent event) onEvent,
}) {
  return impl.postSse(
    dio: dio,
    path: path,
    body: body,
    accessToken: accessToken,
    onEvent: onEvent,
  );
}
