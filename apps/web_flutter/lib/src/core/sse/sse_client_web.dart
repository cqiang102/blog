import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

import 'sse_event.dart';

/// Web 平台 SSE 客户端
/// 使用 XMLHttpRequest 实现增量读取 responseText
Future<List<SseEvent>> postSse({
  required Dio dio,
  required String path,
  required Map<String, dynamic> body,
  required String accessToken,
  required void Function(SseEvent event) onEvent,
}) {
  final completer = Completer<List<SseEvent>>();
  final events = <SseEvent>[];
  final request = web.XMLHttpRequest();

  var processedLength = 0;
  var buffer = '';

  void consume(String chunk, {bool flush = false}) {
    buffer = (buffer + chunk).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    while (true) {
      final index = buffer.indexOf('\n\n');
      if (index == -1) break;

      final block = buffer.substring(0, index);
      buffer = buffer.substring(index + 2);
      for (final event in _parseSseBlock('$block\n\n')) {
        events.add(event);
        onEvent(event);
      }
    }
    if (flush && buffer.trim().isNotEmpty) {
      for (final event in _parseSseBlock('$buffer\n\n')) {
        events.add(event);
        onEvent(event);
      }
      buffer = '';
    }
  }

  void consumeProgress() {
    final text = request.responseText;
    if (text.length <= processedLength) return;
    final chunk = text.substring(processedLength);
    processedLength = text.length;
    consume(chunk);
  }

  // 构建完整 URL
  final base = dio.options.baseUrl.endsWith('/')
      ? dio.options.baseUrl.substring(0, dio.options.baseUrl.length - 1)
      : dio.options.baseUrl;
  final normalizedPath = path.startsWith('/') ? path : '/$path';

  request
    ..open('POST', '$base$normalizedPath')
    ..setRequestHeader('Content-Type', 'application/json')
    ..setRequestHeader('Accept', 'text/event-stream')
    ..setRequestHeader('Authorization', 'Bearer $accessToken')
    ..timeout = const Duration(minutes: 10).inMilliseconds;

  request.onProgress.listen((_) => consumeProgress());
  request.onLoad.listen((_) {
    consumeProgress();
    consume('', flush: true);
    final status = request.status;
    if (status != null && status >= 200 && status < 300) {
      if (!completer.isCompleted) completer.complete(events);
    } else if (!completer.isCompleted) {
      completer.completeError(
        Exception('SSE请求失败 [$status] ${request.responseText}'),
      );
    }
  });
  request.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('SSE网络请求失败'));
    }
  });
  request.ontimeout = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('SSE请求超时'));
    }
  }).toJS;

  request.send(jsonEncode(body).toJS);
  return completer.future;
}

/// 解析 SSE 块为事件列表
List<SseEvent> _parseSseBlock(String block) {
  final events = <SseEvent>[];
  String type = 'message';
  final dataLines = <String>[];

  for (final line in block.split('\n')) {
    if (line.startsWith('event:')) {
      type = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      dataLines.add(line.substring(5).trim());
    }
  }

  if (dataLines.isNotEmpty) {
    events.add(SseEvent(type, dataLines.join('\n')));
  }
  return events;
}
