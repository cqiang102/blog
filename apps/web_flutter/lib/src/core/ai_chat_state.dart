// AI 聊天状态管理
// 使用 Riverpod 管理 AI 聊天的状态

import 'package:flutter_riverpod/legacy.dart';

/// 聊天消息类
class ChatMessage {
  const ChatMessage({
    required this.isMine,
    required this.text,
    this.isError = false,
  });

  final bool isMine;
  final String text;
  final bool isError;

  /// 创建用户消息
  factory ChatMessage.user(String text) {
    return ChatMessage(isMine: true, text: text);
  }

  /// 创建 AI 回复
  factory ChatMessage.ai(String text) {
    return ChatMessage(isMine: false, text: text);
  }

  /// 创建错误消息
  factory ChatMessage.error(String text) {
    return ChatMessage(isMine: false, text: text, isError: true);
  }

  /// 创建空的 AI 回复占位符
  factory ChatMessage.aiPlaceholder() {
    return const ChatMessage(isMine: false, text: '');
  }
}

/// AI 聊天状态类
/// 包含 AI 聊天的所有状态信息
class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.sessionId,
    this.remainingQuestions,
    this.remainingMessages = 40,
    this.isSending = false,
    this.isSessionLimitReached = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final String? sessionId;
  final int? remainingQuestions;
  final int remainingMessages;
  final bool isSending;
  final bool isSessionLimitReached;
  final String? error;

  /// 创建副本并更新部分字段
  AiChatState copyWith({
    List<ChatMessage>? messages,
    String? sessionId,
    int? remainingQuestions,
    int? remainingMessages,
    bool? isSending,
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
      isSessionLimitReached: isSessionLimitReached ?? this.isSessionLimitReached,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// AI 聊天状态通知器
/// 管理 AI 聊天的消息发送、接收等操作
class AiChatNotifier extends StateNotifier<AiChatState> {
  AiChatNotifier() : super(const AiChatState());

  /// 添加用户消息并开始发送
  void addUserMessage(String text) {
    state = state.copyWith(
      messages: [...state.messages, ChatMessage.user(text), ChatMessage.aiPlaceholder()],
      isSending: true,
      clearError: true,
    );
  }

  /// 追加 AI 回复的 token
  void appendAiToken(String token) {
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty && !messages.last.isMine) {
      final last = messages.last;
      messages[messages.length - 1] = ChatMessage.ai(last.text + token);
      state = state.copyWith(messages: messages);
    }
  }

  /// 完成 AI 回复
  void completeAiReply({
    required String sessionId,
    required int remainingQuestions,
    required int remainingMessages,
  }) {
    state = state.copyWith(
      sessionId: sessionId,
      remainingQuestions: remainingQuestions,
      remainingMessages: remainingMessages,
      isSending: false,
      isSessionLimitReached: remainingMessages <= 0,
    );
  }

  /// 设置错误状态
  void setError(String error) {
    state = state.copyWith(
      error: error,
      isSending: false,
    );
  }

  /// 设置会话限制已达到
  void setSessionLimitReached() {
    state = state.copyWith(isSessionLimitReached: true);
  }

  /// 移除空的 AI 占位符消息
  void removeAiPlaceholder() {
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty && !messages.last.isMine && messages.last.text.isEmpty) {
      messages.removeLast();
      state = state.copyWith(messages: messages);
    }
  }

  /// 清除错误状态
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 重置聊天状态
  void reset() {
    state = const AiChatState();
  }

  /// 加载历史消息
  void loadHistory(List<ChatMessage> messages, String sessionId) {
    state = state.copyWith(
      messages: messages,
      sessionId: sessionId,
    );
  }
}
