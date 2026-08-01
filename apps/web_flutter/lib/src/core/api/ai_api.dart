// AI 相关 API
// 包含 AI 聊天、配额、会话管理等

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../models.dart';
import '../sse/sse_client.dart';
import '../sse/sse_event.dart';
import 'api_client_base.dart';

/// 生成一个 UUID v4，用作 SSE 聊天请求的幂等键。
///
/// 服务端可基于该 ID 对同一消息的重试进行去重，避免 401 刷新令牌后
/// 重新 POST 时产生重复的 AI 回答。
String _generateRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  // 设置版本号 (4) 与变体 (10xx) 位，符合 RFC 4122 v4。
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// AI 相关 API Mixin
mixin AiApi on ApiClientBase {
  /// 获取 AI 配额
  Future<AiQuota> fetchAiQuota(String accessToken) async {
    final data = await get('/ai/quota', accessToken: accessToken);
    return decodeObject(data, AiQuota.fromJson);
  }

  /// 发送 AI 聊天消息（SSE 流式）
  Stream<SseEvent> sendAiMessageStream({
    required String accessToken,
    required String message,
    String? sessionId,
  }) {
    final cancellationToken = SseCancellationToken();
    final controller = StreamController<SseEvent>(
      onCancel: cancellationToken.cancel,
    );

    _postSseWithRetry(
      accessToken: accessToken,
      message: message,
      sessionId: sessionId,
      controller: controller,
      cancellationToken: cancellationToken,
    );

    return controller.stream;
  }

  Future<void> _postSseWithRetry({
    required String accessToken,
    required String message,
    required String? sessionId,
    required StreamController<SseEvent> controller,
    required SseCancellationToken cancellationToken,
  }) async {
    // 每次发送生成一个幂等键；401 重试时复用同一个 requestId，
    // 让服务端能够对重复请求去重。
    final requestId = _generateRequestId();
    var receivedAnyEvent = false;
    void emitEvent(SseEvent event) {
      receivedAnyEvent = true;
      if (!controller.isClosed) controller.add(event);
    }

    try {
      await postSse(
        dio: dio,
        path: '/ai/chat/stream',
        body: {
          'sessionId': sessionId,
          'message': message,
          'requestId': requestId,
        },
        accessToken: accessToken,
        onEvent: emitEvent,
        cancellationToken: cancellationToken,
      );
      if (!controller.isClosed) controller.close();
    } catch (e, stackTrace) {
      if (cancellationToken.isCancelled) {
        if (!controller.isClosed) await controller.close();
        return;
      }
      if (e is SseRequestException &&
          e.statusCode == 401 &&
          onUnauthorized != null) {
        // 如果在收到 401 之前已经有 token/事件流出，说明服务端可能已经
        // 开始处理这条消息，重放会导致重复回答 —— 此时直接以错误结束。
        if (receivedAnyEvent) {
          if (!controller.isClosed) {
            controller.addError(e, stackTrace);
            await controller.close();
          }
          return;
        }
        // 等待一小段时间，让可能正在进行的刷新完成
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final newToken = await onUnauthorized!();
        if (newToken != null &&
            !controller.isClosed &&
            !cancellationToken.isCancelled) {
          try {
            await postSse(
              dio: dio,
              path: '/ai/chat/stream',
              body: {
                'sessionId': sessionId,
                'message': message,
                'requestId': requestId,
              },
              accessToken: newToken,
              onEvent: emitEvent,
              cancellationToken: cancellationToken,
            );
            if (!controller.isClosed) controller.close();
          } catch (retryError, retryStackTrace) {
            if (!controller.isClosed) {
              controller.addError(retryError, retryStackTrace);
              await controller.close();
            }
          }
          return;
        }
      }
      if (!controller.isClosed) {
        controller.addError(e, stackTrace);
        await controller.close();
      }
    }
  }

  /// 创建 AI 会话
  Future<AiSessionItem> createAiSession({
    required String accessToken,
    String? title,
  }) async {
    final data = await post(
      '/ai/sessions',
      accessToken: accessToken,
      body: {'title': ?title},
    );
    return decodeObject(data, AiSessionItem.fromJson);
  }

  /// 获取 AI 会话列表
  Future<List<AiSessionItem>> fetchAiSessions(String accessToken) async {
    final data = await get('/ai/sessions', accessToken: accessToken);
    return decodeObjectList(data, AiSessionItem.fromJson);
  }

  /// 删除 AI 会话
  Future<void> deleteAiSession({
    required String accessToken,
    required String sessionId,
  }) async {
    await delete('/ai/sessions/$sessionId', accessToken: accessToken);
  }

  /// 获取 AI 会话消息列表
  Future<PageResult<AiMessageItem>> fetchAiSessionMessages({
    required String accessToken,
    required String sessionId,
    int page = 0,
    int size = 50,
    CancelToken? cancelToken,
  }) async {
    final data = await get(
      '/ai/sessions/$sessionId/messages',
      accessToken: accessToken,
      cancelToken: cancelToken,
      queryParameters: {'page': page.toString(), 'size': size.toString()},
    );
    return pageResult(data, AiMessageItem.fromJson);
  }
}
