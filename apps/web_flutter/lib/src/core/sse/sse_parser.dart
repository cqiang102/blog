// SSE 协议解析工具
// 提供 SSE 块解析为事件列表的通用逻辑

import 'sse_event.dart';

/// 解析 SSE 块为事件列表
/// [block] 包含一个或多个 SSE 消息的文本块（以 \n\n 分隔）
List<SseEvent> parseSseBlock(String block) {
  final events = <SseEvent>[];
  String type = 'message';
  final dataLines = <String>[];

  for (final line in block.split('\n')) {
    if (line.startsWith('event:')) {
      type = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      final value = line.substring(5);
      dataLines.add(value.startsWith(' ') ? value.substring(1) : value);
    }
  }

  if (dataLines.isNotEmpty) {
    final data =
        type == 'token' && dataLines.length == 1 && dataLines.single.isEmpty
        ? '\n'
        : dataLines.join('\n');
    events.add(SseEvent(type, data));
  }
  return events;
}

/// SSE 流消费回调
/// 用于 web 和 io 平台的 SSE 客户端共享 consume 逻辑
typedef SseEventHandler = void Function(SseEvent event);

/// 处理 SSE 数据块，解析并分发事件
/// [buffer] 当前缓冲区（会被修改）
/// [chunk] 新到达的数据块
/// [onEvent] 事件回调
/// [flush] 是否刷新剩余缓冲区
/// 返回更新后的缓冲区
String consumeSseChunk({
  required String buffer,
  required String chunk,
  required SseEventHandler onEvent,
  bool flush = false,
}) {
  buffer = (buffer + chunk).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  while (true) {
    final index = buffer.indexOf('\n\n');
    if (index == -1) break;

    final block = buffer.substring(0, index);
    buffer = buffer.substring(index + 2);
    for (final event in parseSseBlock('$block\n\n')) {
      onEvent(event);
    }
  }
  if (flush && buffer.trim().isNotEmpty) {
    for (final event in parseSseBlock('$buffer\n\n')) {
      onEvent(event);
    }
    buffer = '';
  }
  return buffer;
}
