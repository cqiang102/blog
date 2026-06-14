// AI 相关 API
// 包含 AI 聊天、配额、会话管理等

import 'dart:async';

import '../models.dart';
import '../sse/sse_client.dart';
import '../sse/sse_event.dart';
import 'api_client_base.dart';

/// AI 相关 API Mixin
mixin AiApi on ApiClientBase {
  /// 获取 AI 配额
  Future<AiQuota> fetchAiQuota(String accessToken) async {
    final data = await get('/ai/quota', accessToken: accessToken);
    return AiQuota.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 发送 AI 聊天消息
  Future<AiChatReply> sendAiMessage({
    required String accessToken,
    required String message,
    String? sessionId,
  }) async {
    final data = await post(
      '/ai/chat',
      accessToken: accessToken,
      body: {'sessionId': sessionId, 'message': message},
    );
    return AiChatReply.fromJson((data as Map).cast<String, dynamic>());
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
    try {
      await postSse(
        dio: dio,
        path: '/ai/chat/stream',
        body: {'sessionId': sessionId, 'message': message},
        accessToken: accessToken,
        onEvent: (event) {
          if (!controller.isClosed) controller.add(event);
        },
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
              body: {'sessionId': sessionId, 'message': message},
              accessToken: newToken,
              onEvent: (event) {
                if (!controller.isClosed) controller.add(event);
              },
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
      body: {if (title != null) 'title': title},
    );
    return AiSessionItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取 AI 会话列表
  Future<List<AiSessionItem>> fetchAiSessions(String accessToken) async {
    final data = await get('/ai/sessions', accessToken: accessToken);
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => AiSessionItem.fromJson(item.cast<String, dynamic>()))
        .toList();
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
  }) async {
    final data = await get(
      '/ai/sessions/$sessionId/messages',
      accessToken: accessToken,
      queryParameters: {'page': page.toString(), 'size': size.toString()},
    );
    return pageResult(data, AiMessageItem.fromJson);
  }
}
