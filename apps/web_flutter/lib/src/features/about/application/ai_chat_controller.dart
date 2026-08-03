import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/models.dart';
import '../../../core/sse/sse_event.dart';
import '../../../state/api_providers.dart';

final aiQuotaProvider = FutureProvider<AiQuota>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAiQuota(token);
});

final aiChatControllerProvider =
    NotifierProvider.autoDispose<AiChatController, AiChatState>(
      AiChatController.new,
    );

enum AiChatSendOutcome { started, loginRequired, ignored }

class ChatMessage {
  const ChatMessage({
    required this.isMine,
    required this.text,
    this.isError = false,
  });

  final bool isMine;
  final String text;
  final bool isError;

  factory ChatMessage.user(String text) {
    return ChatMessage(isMine: true, text: text);
  }

  factory ChatMessage.ai(String text) {
    return ChatMessage(isMine: false, text: text);
  }

  factory ChatMessage.error(String text) {
    return ChatMessage(isMine: false, text: text, isError: true);
  }

  factory ChatMessage.aiPlaceholder() {
    return const ChatMessage(isMine: false, text: '');
  }
}

class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.sessionId,
    this.remainingQuestions,
    this.remainingMessages = 40,
    this.isSending = false,
    this.isLoadingHistory = false,
    this.isSessionLimitReached = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final String? sessionId;
  final int? remainingQuestions;
  final int remainingMessages;
  final bool isSending;
  final bool isLoadingHistory;
  final bool isSessionLimitReached;
  final String? error;

  AiChatState copyWith({
    List<ChatMessage>? messages,
    String? sessionId,
    int? remainingQuestions,
    int? remainingMessages,
    bool? isSending,
    bool? isLoadingHistory,
    bool? isSessionLimitReached,
    String? error,
    bool clearSessionId = false,
    bool clearError = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      remainingQuestions: remainingQuestions ?? this.remainingQuestions,
      remainingMessages: remainingMessages ?? this.remainingMessages,
      isSending: isSending ?? this.isSending,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isSessionLimitReached:
          isSessionLimitReached ?? this.isSessionLimitReached,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class _ActiveChatRequest {
  final completion = Completer<void>();
  StreamSubscription<SseEvent>? subscription;
  bool terminalEventReceived = false;
  bool cancelled = false;
}

class AiChatController extends Notifier<AiChatState> {
  _ActiveChatRequest? _activeChat;
  CancelToken? _historyCancelToken;
  int _historyGeneration = 0;
  bool _disposed = false;

  /// Token buffer to batch SSE token updates and avoid per-token rebuilds.
  final StringBuffer _tokenBuffer = StringBuffer();
  Timer? _flushTimer;

  @override
  AiChatState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _historyGeneration += 1;
      _historyCancelToken?.cancel('AI history controller disposed');
      // _cancelActiveChat 不会停止 token 缓冲区计时器，这里直接清理，
      // 避免 dispose 后周期性 Timer 继续触发。
      _flushTimer?.cancel();
      _flushTimer = null;
      _tokenBuffer.clear();
      unawaited(_cancelActiveChat(updateState: false));
    });
    return const AiChatState();
  }

  int _beginHistoryOperation() {
    _historyCancelToken?.cancel('Superseded by a newer chat operation');
    _historyCancelToken = null;
    return ++_historyGeneration;
  }

  Future<void> loadLatestSession() async {
    final generation = _beginHistoryOperation();
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final sessions = await ref.read(apiClientProvider).fetchAiSessions(token);
      if (_disposed || generation != _historyGeneration || sessions.isEmpty) {
        return;
      }
      await _loadHistory(sessions.first.id, generation);
    } on ApiException catch (error) {
      if (_disposed || generation != _historyGeneration) return;
      // 仅把“没有会话”类的错误（404 / 资源不存在）当作空会话静默处理；
      // 其余错误（500、超时、网络等）需要暴露给 UI 以便提示重试。
      final isNoSession =
          error.statusCode == 404 || error.message.contains('不存在');
      if (isNoSession) return;
      _setError('加载会话失败，请重试');
    }
  }

  Future<void> loadHistory(String sessionId) async {
    final generation = _beginHistoryOperation();
    await _loadHistory(sessionId, generation);
  }

  Future<void> _loadHistory(String sessionId, int generation) async {
    await cancelActiveChat();
    if (_disposed || generation != _historyGeneration) return;
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    state = state.copyWith(isLoadingHistory: true, clearError: true);
    _historyCancelToken?.cancel('Superseded by a newer history request');
    final cancelToken = CancelToken();
    _historyCancelToken = cancelToken;
    try {
      final page = await ref
          .read(apiClientProvider)
          .fetchAiSessionMessages(
            accessToken: token,
            sessionId: sessionId,
            size: 50,
            cancelToken: cancelToken,
          );
      if (_disposed || generation != _historyGeneration) return;

      final messages = page.items
          .map(
            (message) => ChatMessage(
              isMine: message.role == 'USER',
              text: message.auditStatus == 'BLOCKED'
                  ? '该内容不适合展示'
                  : message.content,
            ),
          )
          .toList();
      state = state.copyWith(
        messages: messages,
        sessionId: sessionId,
        isSending: false,
        isSessionLimitReached: messages.length >= 40,
        clearError: true,
      );
    } on ApiException catch (error) {
      if (cancelToken.isCancelled) return;
      if (!_disposed && generation == _historyGeneration) {
        _setError(error.message);
      }
    } finally {
      if (identical(_historyCancelToken, cancelToken)) {
        _historyCancelToken = null;
      }
      if (!_disposed && generation == _historyGeneration) {
        state = state.copyWith(isLoadingHistory: false);
      }
    }
  }

  Future<void> createNewSession() async {
    final generation = _beginHistoryOperation();
    await cancelActiveChat();
    if (_disposed || generation != _historyGeneration) return;
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final session = await ref
          .read(apiClientProvider)
          .createAiSession(accessToken: token);
      if (_disposed || generation != _historyGeneration) return;
      state = AiChatState(sessionId: session.id);
    } on ApiException catch (error) {
      if (!_disposed && generation == _historyGeneration) {
        _setError(error.message);
      }
    }
  }

  Future<List<AiSessionItem>> fetchSessions() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return const [];
    try {
      return await ref.read(apiClientProvider).fetchAiSessions(token);
    } on ApiException catch (error) {
      if (!_disposed) _setError(error.message);
      return const [];
    }
  }

  Future<void> deleteSession(String sessionId) async {
    final deletingCurrentSession = state.sessionId == sessionId;
    final generation = deletingCurrentSession
        ? _beginHistoryOperation()
        : _historyGeneration;
    if (deletingCurrentSession) {
      // Stop token/done callbacks before deleting the backing session.
      await cancelActiveChat();
      if (_disposed) return;
    }
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .deleteAiSession(accessToken: token, sessionId: sessionId);
      if (!_disposed &&
          generation == _historyGeneration &&
          state.sessionId == sessionId) {
        state = const AiChatState();
      }
    } on ApiException catch (error) {
      if (!_disposed && generation == _historyGeneration) {
        _setError(error.message);
      }
    }
  }

  Future<AiChatSendOutcome> send(String rawText) async {
    if (state.isSending) return AiChatSendOutcome.ignored;

    final text = rawText.trim();
    if (text.isEmpty ||
        state.isSessionLimitReached ||
        (state.remainingQuestions != null && state.remainingQuestions! <= 0)) {
      return AiChatSendOutcome.ignored;
    }

    final generation = _beginHistoryOperation();
    final token = await ref.read(authControllerProvider).getValidAccessToken();
    if (_disposed || generation != _historyGeneration) {
      return AiChatSendOutcome.ignored;
    }
    if (token == null) return AiChatSendOutcome.loginRequired;

    await cancelActiveChat();
    if (_disposed || generation != _historyGeneration) {
      return AiChatSendOutcome.ignored;
    }

    addUserMessage(text);
    unawaited(
      _runStream(accessToken: token, sessionId: state.sessionId, message: text),
    );
    return AiChatSendOutcome.started;
  }

  Future<void> _runStream({
    required String accessToken,
    required String? sessionId,
    required String message,
  }) async {
    _ActiveChatRequest? activeChat;
    try {
      final stream = ref
          .read(apiClientProvider)
          .sendAiMessageStream(
            accessToken: accessToken,
            sessionId: sessionId,
            message: message,
          );
      final request = _ActiveChatRequest();
      activeChat = request;
      _activeChat = request;
      request.subscription = stream.listen(
        (event) => _handleEvent(request, event),
        onError: (Object error, StackTrace stackTrace) {
          request.terminalEventReceived = true;
          if (!request.completion.isCompleted) {
            request.completion.completeError(error, stackTrace);
          }
        },
        onDone: () {
          if (!request.cancelled &&
              !request.terminalEventReceived &&
              !_disposed) {
            removeAiPlaceholder(force: true);
            _setError('连接提前中断，请重试');
          }
          if (!request.completion.isCompleted) {
            request.completion.complete();
          }
        },
        cancelOnError: true,
      );
      await request.completion.future;
    } on ApiException catch (error) {
      if (_disposed) return;
      if (error.message.contains('会话消息数已达上限')) {
        setSessionLimitReached();
      }
      removeAiPlaceholder(force: true);
      _setError(error.message);
    } catch (error, stackTrace) {
      if (_disposed) return;
      // 记录被吞掉的异常，便于线上定位 SSE 流式失败的真实原因。
      debugPrint('AI chat SSE error: $error\n$stackTrace');
      removeAiPlaceholder(force: true);
      _setError(userFacingErrorMessage(error));
    } finally {
      stopTokenBuffer();
      if (identical(_activeChat, activeChat)) {
        _activeChat = null;
      }
    }
  }

  void _handleEvent(_ActiveChatRequest request, SseEvent event) {
    if (_disposed || request.cancelled) return;
    try {
      switch (event.type) {
        case 'token':
          appendAiToken(event.data);
        case 'done':
          request.terminalEventReceived = true;
          final reply = AiChatReply.fromJson(
            (jsonDecode(event.data) as Map).cast<String, dynamic>(),
          );
          completeAiReply(
            sessionId: reply.sessionId,
            answer: reply.answer,
            remainingQuestions: reply.remainingQuestions,
            remainingMessages: reply.remainingMessages,
          );
          ref.invalidate(aiQuotaProvider);
        case 'error':
          request.terminalEventReceived = true;
          removeAiPlaceholder(force: true);
          final message =
              event.data.contains('提问次数') || event.data.contains('配额')
              ? '今日提问次数已用完'
              : event.data;
          _setError(message);
      }
    } catch (error, stackTrace) {
      request.terminalEventReceived = true;
      if (!request.completion.isCompleted) {
        request.completion.completeError(error, stackTrace);
      }
      final subscription = request.subscription;
      if (subscription != null) unawaited(subscription.cancel());
    }
  }

  Future<void> cancelActiveChat() {
    return _cancelActiveChat(updateState: true);
  }

  Future<void> _cancelActiveChat({required bool updateState}) async {
    final activeChat = _activeChat;
    if (activeChat == null) return;

    _activeChat = null;
    activeChat.cancelled = true;
    await activeChat.subscription?.cancel();
    if (!activeChat.completion.isCompleted) {
      activeChat.completion.complete();
    }
    if (updateState && !_disposed) cancelSending();
  }

  void addUserMessage(String text) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage.user(text),
        ChatMessage.aiPlaceholder(),
      ],
      isSending: true,
      clearError: true,
    );
  }

  void appendAiToken(String token) {
    _tokenBuffer.write(token);
    _flushTimer ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _flushTokenBuffer(),
    );
  }

  /// Flushes buffered tokens into state in a single rebuild.
  void _flushTokenBuffer() {
    // 若控制器已释放，或当前会话已被取消，丢弃缓冲的 token，避免会话 A 的
    // token 被追加到会话 B 的消息上。取消路径都会把 cancelled 置为 true；
    // 正常结束时 cancelled 仍为 false，因此最后一批 token 仍会被刷新出来。
    if (_disposed || (_activeChat?.cancelled ?? false)) {
      _tokenBuffer.clear();
      return;
    }
    if (_tokenBuffer.isEmpty) return;
    final buffered = _tokenBuffer.toString();
    _tokenBuffer.clear();
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty && !messages.last.isMine) {
      final last = messages.last;
      messages[messages.length - 1] = ChatMessage.ai(last.text + buffered);
      state = state.copyWith(messages: messages);
    }
  }

  /// Cancels the flush timer and flushes any remaining buffered tokens.
  void stopTokenBuffer() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _flushTokenBuffer();
  }

  void completeAiReply({
    required String sessionId,
    required String answer,
    required int remainingQuestions,
    required int remainingMessages,
  }) {
    // 若控制器已释放，或当前会话已被取消，不能用旧会话的结果覆盖状态。
    // done 事件与 createNewSession 竞态时，下方的 sessionId 校验会避免把
    // 新会话的 ID 回退成旧会话的 ID。
    if (_disposed || (_activeChat?.cancelled ?? false)) return;
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty && !messages.last.isMine) {
      messages[messages.length - 1] = ChatMessage.ai(answer);
    }
    // 仅当当前 sessionId 为空或与本次回答一致时才写入，避免把新会话的
    // sessionId 回退成旧会话的 ID。
    final shouldUpdateSessionId =
        state.sessionId == null || state.sessionId == sessionId;
    state = state.copyWith(
      messages: messages,
      sessionId: shouldUpdateSessionId ? sessionId : state.sessionId,
      remainingQuestions: remainingQuestions,
      remainingMessages: remainingMessages,
      isSending: false,
      isSessionLimitReached: remainingMessages <= 0,
    );
  }

  void setSessionLimitReached() {
    state = state.copyWith(isSessionLimitReached: true);
  }

  void removeAiPlaceholder({bool force = false}) {
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isEmpty || messages.last.isMine) return;
    // force=true 用于错误路径：即便已经流出了部分文本，也移除这条不完整的
    // 回答，避免残缺内容被当作有效回复保留下来。
    if (force || messages.last.text.isEmpty) {
      messages.removeLast();
      state = state.copyWith(messages: messages);
    }
  }

  void cancelSending() {
    if (!state.isSending) return;
    stopTokenBuffer();
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty &&
        !messages.last.isMine &&
        messages.last.text.isEmpty) {
      messages.removeLast();
    }
    state = state.copyWith(messages: messages, isSending: false);
  }

  void reset() {
    state = const AiChatState();
  }

  void _setError(String message) {
    state = state.copyWith(error: message, isSending: false);
  }
}
