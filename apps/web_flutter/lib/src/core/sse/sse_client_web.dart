import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

import 'sse_event.dart';
import 'sse_parser.dart';
import 'sse_request.dart';

/// SSE 请求超时时间
const _sseTimeout = Duration(minutes: 10);

/// Web 平台 SSE 客户端
/// 使用 Fetch API + ReadableStream 实现真正的流式读取
Future<List<SseEvent>> postSse({
  required Dio dio,
  required String path,
  required Map<String, dynamic> body,
  required String accessToken,
  required void Function(SseEvent event) onEvent,
  SseCancellationToken? cancellationToken,
}) async {
  final events = <SseEvent>[];
  var buffer = '';

  void consume(String chunk, {bool flush = false}) {
    buffer = consumeSseChunk(
      buffer: buffer,
      chunk: chunk,
      onEvent: (event) {
        events.add(event);
        onEvent(event);
      },
      flush: flush,
    );
  }

  // 构建完整 URL
  final base = dio.options.baseUrl.endsWith('/')
      ? dio.options.baseUrl.substring(0, dio.options.baseUrl.length - 1)
      : dio.options.baseUrl;
  final normalizedPath = path.startsWith('/') ? path : '/$path';

  // 使用 AbortController 实现超时控制
  final abortController = web.AbortController();
  cancellationToken?.bind(() => abortController.abort());
  final timer = Timer(_sseTimeout, () => abortController.abort());

  try {
    final response = await web.window
        .fetch(
          '$base$normalizedPath'.toJS,
          web.RequestInit(
            method: 'POST',
            body: jsonEncode(body).toJS,
            headers:
                {
                      'Content-Type': 'application/json',
                      'Accept': 'text/event-stream',
                      'Authorization': 'Bearer $accessToken',
                    }.jsify()!
                    as JSObject,
            signal: abortController.signal,
          ),
        )
        .toDart;

    if (!response.ok) {
      final status = response.status;
      final text = (await response.text().toDart).toDart;
      throw SseRequestException(
        text.isEmpty ? 'SSE 请求失败' : text,
        statusCode: status,
      );
    }

    final bodyStream = response.body;
    if (bodyStream == null) {
      consume('', flush: true);
      return events;
    }

    final reader = bodyStream.getReader() as web.ReadableStreamDefaultReader;
    try {
      Stream<List<int>> readBytes() async* {
        while (true) {
          if (cancellationToken?.isCancelled ?? false) return;
          final result = await reader.read().toDart;
          if (result.done) return;
          yield (result.value! as JSUint8Array).toDart;
        }
      }

      await for (final chunk in readBytes().transform(utf8.decoder)) {
        if (chunk.isNotEmpty) {
          consume(chunk);
        }
      }
      consume('', flush: true);
    } finally {
      reader.releaseLock();
    }
  } finally {
    timer.cancel();
    cancellationToken?.bind(null);
  }

  return events;
}
