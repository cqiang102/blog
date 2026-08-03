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

  // 构建完整 URL
  final base = dio.options.baseUrl.endsWith('/')
      ? dio.options.baseUrl.substring(0, dio.options.baseUrl.length - 1)
      : dio.options.baseUrl;
  final normalizedPath = path.startsWith('/') ? path : '/$path';

  // 使用 AbortController 实现超时控制。
  // Wasm 兼容：部分环境下 AbortController 构造可能抛错，失败时降级为无信号，
  // 避免整个 SSE 请求在发出前就失败。
  web.AbortController? abortController;
  try {
    abortController = web.AbortController();
  } catch (_) {
    abortController = null;
  }
  cancellationToken?.bind(() => abortController?.abort());
  final timer = Timer(_sseTimeout, () => abortController?.abort());

  // Wasm 兼容：使用 Headers 对象构造请求头，避免 Map.jsify() 在 Wasm 下的
  // 互操作问题导致请求在发出前抛错。
  final headers = web.Headers();
  headers.append('Content-Type', 'application/json');
  headers.append('Accept', 'text/event-stream');
  headers.append('Authorization', 'Bearer $accessToken');

  try {
    final response = await web.window
        .fetch(
          '$base$normalizedPath'.toJS,
          web.RequestInit(
            method: 'POST',
            body: jsonEncode(body).toJS,
            headers: headers,
            signal: abortController?.signal,
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
      return;
    }

    final reader = bodyStream.getReader() as web.ReadableStreamDefaultReader;
    try {
      Stream<List<int>> readBytes() async* {
        while (true) {
          if (cancellationToken?.isCancelled ?? false) return;
          final result = await reader.read().toDart;
          if (result.done) return;
          final value = result.value;
          if (value == null) continue;
          yield (value as JSUint8Array).toDart;
        }
      }

      await for (final chunk in readBytes().transform(utf8.decoder)) {
        if (chunk.isNotEmpty) {
          consume(chunk);
        }
      }
      consume('', flush: true);
    } finally {
      try {
        await reader.cancel().toDart;
      } catch (_) {
        // Stream may already be closed; safe to ignore.
      }
      reader.releaseLock();
    }
  } finally {
    timer.cancel();
    cancellationToken?.bind(null);
  }
}
