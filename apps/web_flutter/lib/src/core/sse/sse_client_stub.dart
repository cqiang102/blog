import 'dart:async';

import 'package:dio/dio.dart';

import 'sse_event.dart';
import 'sse_request.dart';

/// 不支持 SSE 的平台抛出异常
Future<List<SseEvent>> postSse({
  required Dio dio,
  required String path,
  required Map<String, dynamic> body,
  required String accessToken,
  required void Function(SseEvent event) onEvent,
  SseCancellationToken? cancellationToken,
}) {
  throw UnsupportedError('当前平台不支持 SSE');
}
