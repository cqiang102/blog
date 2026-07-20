import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'sse_event.dart';
import 'sse_parser.dart';
import 'sse_request.dart';

/// SSE 请求超时时间
const _sseTimeout = Duration(minutes: 10);

/// IO 平台（移动端/桌面端）SSE 客户端
/// 使用 Dio 的 ResponseType.stream 读取字节流
Future<void> postSse({
  required Dio dio,
  required String path,
  required Map<String, dynamic> body,
  required String accessToken,
  required void Function(SseEvent event) onEvent,
  SseCancellationToken? cancellationToken,
}) async {
  var buffer = '';

  void consume(String chunk, {bool flush = false}) {
    buffer = consumeSseChunk(
      buffer: buffer,
      chunk: chunk,
      onEvent: onEvent,
      flush: flush,
    );
  }

  final dioCancelToken = CancelToken();
  cancellationToken?.bind(() => dioCancelToken.cancel('SSE request cancelled'));

  try {
    final response = await dio.post<ResponseBody>(
      path,
      data: body,
      cancelToken: dioCancelToken,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer $accessToken',
        },
        responseType: ResponseType.stream,
        receiveTimeout: _sseTimeout,
      ),
    );

    final responseBody = response.data;
    if (responseBody == null) return;

    await for (final chunk in responseBody.stream.cast<List<int>>().transform(
      utf8.decoder,
    )) {
      if (cancellationToken?.isCancelled ?? false) break;
      consume(chunk);
    }
    consume('', flush: true);
  } on DioException catch (error) {
    if (CancelToken.isCancel(error) &&
        (cancellationToken?.isCancelled ?? false)) {
      return;
    }
    throw SseRequestException(
      error.response?.data?.toString() ?? error.message ?? 'SSE 请求失败',
      statusCode: error.response?.statusCode,
    );
  } finally {
    cancellationToken?.bind(null);
  }
}
