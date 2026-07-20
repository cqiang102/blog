import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/sse/sse_client.dart';
import 'package:personal_blog_web/src/core/sse/sse_event.dart';

class _StreamingAdapter implements HttpClientAdapter {
  _StreamingAdapter(this.chunks);

  final List<String> chunks;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream.fromIterable(
        chunks.map((chunk) => Uint8List.fromList(utf8.encode(chunk))),
      ),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('postSse streams events through the callback and completes', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://sse.test'));
    dio.httpClientAdapter = _StreamingAdapter([
      'event: token\ndata: hel',
      'lo\n\nevent: done\ndata: {}\n\n',
    ]);
    addTearDown(dio.close);
    final events = <SseEvent>[];

    await postSse(
      dio: dio,
      path: '/stream',
      body: const {'message': 'hello'},
      accessToken: 'token',
      onEvent: events.add,
    );

    expect(events.map((event) => event.type), ['token', 'done']);
    expect(events.first.data, 'hello');
  });
}
