import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'sse_event.dart';
import 'sse_parser.dart';

/// SSE 请求超时时间
const _sseTimeout = Duration(minutes: 10);

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
      receiveTimeout: _sseTimeout,
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
