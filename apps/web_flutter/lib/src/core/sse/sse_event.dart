/// SSE 事件模型
class SseEvent {
  final String type;
  final String data;

  const SseEvent(this.type, this.data);

  @override
  String toString() => 'SseEvent($type, $data)';
}
