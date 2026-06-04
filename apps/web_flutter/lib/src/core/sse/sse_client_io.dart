import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'sse_event.dart';

/// IO 平台（移动端/桌面端）SSE 客户端
/// 使用 Dio 的 ResponseType.stream 读取字节流
Future<List<SseEvent>> postSse({
  required Dio dio,
  required String path,
  required Map<String, dynamic> body,
  required String accessToken,
  required void Function(SseEvent event) onEvent,
}) async {
  final events = <SseEvent>[];
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

  final response = await dio.post<ResponseBody>(
    path,
    data: body,
    options: Options(
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Authorization': 'Bearer $accessToken',
      },
      responseType: ResponseType.stream,
      receiveTimeout: const Duration(minutes: 10),
    ),
  );

  final responseBody = response.data;
  if (responseBody == null) return events;

  final stream = responseBody.stream.cast<Uint8List>();
  await for (final chunk in stream.transform(const _SseByteTransformer())) {
    consume(chunk);
  }
  consume('', flush: true);
  return events;
}

/// 立即把字节转换为字符串的流转换器
class _SseByteTransformer extends StreamTransformerBase<Uint8List, String> {
  const _SseByteTransformer();

  @override
  Stream<String> bind(Stream<Uint8List> stream) {
    final controller = StreamController<String>();
    stream.listen(
      (chunk) {
        final text = utf8.decode(chunk, allowMalformed: true);
        if (text.isNotEmpty) controller.add(text);
      },
      onError: controller.addError,
      onDone: controller.close,
    );
    return controller.stream;
  }
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
