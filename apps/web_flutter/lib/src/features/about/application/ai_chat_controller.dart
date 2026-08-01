import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
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
    } on ApiException {
      // A user without previous sessions starts with an empty conversation.
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
            removeAiPlaceholder();
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
      removeAiPlaceholder();
      _setError(error.message);
    } catch (error) {
      if (_disposed) return;
      removeAiPlaceholder();
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
          removeAiPlaceholder();
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
    if (_tokenBuffer.isEmpty) return;
    final buffered = _tokenBuffer.toString();
    _tokenBuffer.clear();
    if (_disposed) return;
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
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty && !messages.last.isMine) {
      messages[messages.length - 1] = ChatMessage.ai(answer);
    }
    state = state.copyWith(
      messages: messages,
      sessionId: sessionId,
      remainingQuestions: remainingQuestions,
      remainingMessages: remainingMessages,
      isSending: false,
      isSessionLimitReached: remainingMessages <= 0,
    );
  }

  void setSessionLimitReached() {
    state = state.copyWith(isSessionLimitReached: true);
  }

  void removeAiPlaceholder() {
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty &&
        !messages.last.isMine &&
        messages.last.text.isEmpty) {
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
