// AI 相关数据模型
// 包含 AI 配额、聊天回复、会话、消息等

import 'enums.dart';
import 'helpers.dart';

/// AI 配额模型
class AiQuota {
  const AiQuota({required this.dailyLimit, required this.used});

  final int dailyLimit;
  final int used;

  /// 剩余配额
  int get remaining => dailyLimit - used;

  /// 从 JSON 创建实例
  factory AiQuota.fromJson(Map<String, dynamic> json) {
    return AiQuota(
      dailyLimit: jsonInt(json['dailyLimit']),
      used: jsonInt(json['used']),
    );
  }
}

/// AI 聊天回复模型
class AiChatReply {
  const AiChatReply({
    required this.sessionId,
    required this.answer,
    required this.remainingQuestions,
    required this.remainingMessages,
  });

  final String sessionId;
  final String answer;
  final int remainingQuestions;
  final int remainingMessages;

  /// 从 JSON 创建实例
  factory AiChatReply.fromJson(Map<String, dynamic> json) {
    return AiChatReply(
      sessionId: jsonString(json['sessionId']),
      answer: jsonString(json['answer']),
      remainingQuestions: jsonInt(json['remainingQuestions']),
      remainingMessages: jsonInt(json['remainingMessages']),
    );
  }
}

/// AI 会话项模型
class AiSessionItem {
  const AiSessionItem({
    required this.id,
    required this.title,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 从 JSON 创建实例
  factory AiSessionItem.fromJson(Map<String, dynamic> json) {
    return AiSessionItem(
      id: jsonString(json['id']),
      title: jsonString(json['title']),
      messageCount: jsonInt(json['messageCount']),
      createdAt: jsonDate(json['createdAt']),
      updatedAt: jsonDate(json['updatedAt']),
    );
  }
}

/// AI 消息项模型
class AiMessageItem {
  const AiMessageItem({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String content;
  final DateTime createdAt;

  /// 从 JSON 创建实例
  factory AiMessageItem.fromJson(Map<String, dynamic> json) {
    return AiMessageItem(
      id: jsonString(json['id']),
      role: jsonString(json['role']),
      content: jsonString(json['content']),
      createdAt: jsonDate(json['createdAt']),
    );
  }
}

/// 管理后台 AI 聊天会话项模型
class AdminAiChatSessionItem {
  const AdminAiChatSessionItem({
    required this.id,
    required this.userId,
    required this.userNickname,
    required this.userEmail,
    required this.title,
    required this.messageCount,
    required this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String userNickname;
  final String userEmail;
  final String title;
  final int messageCount;
  final String lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 从 JSON 创建实例
  factory AdminAiChatSessionItem.fromJson(Map<String, dynamic> json) {
    return AdminAiChatSessionItem(
      id: jsonString(json['id']),
      userId: jsonString(json['userId']),
      userNickname: jsonString(json['userNickname']),
      userEmail: jsonString(json['userEmail']),
      title: jsonString(json['title']),
      messageCount: jsonInt(json['messageCount']),
      lastMessage: jsonString(json['lastMessage']),
      createdAt: jsonDate(json['createdAt']),
      updatedAt: jsonDate(json['updatedAt']),
    );
  }
}

/// 管理后台 AI 聊天消息项模型
class AdminAiChatMessageItem {
  const AdminAiChatMessageItem({
    required this.id,
    required this.role,
    required this.content,
    required this.toolName,
    required this.promptTokens,
    required this.completionTokens,
    required this.createdAt,
  });

  final String id;
  final AiChatMessageRole role;
  final String content;
  final String toolName;
  final int promptTokens;
  final int completionTokens;
  final DateTime createdAt;

  /// 从 JSON 创建实例
  factory AdminAiChatMessageItem.fromJson(Map<String, dynamic> json) {
    return AdminAiChatMessageItem(
      id: jsonString(json['id']),
      role: AiChatMessageRole.fromApi(jsonString(json['role'])),
      content: jsonString(json['content']),
      toolName: jsonString(json['toolName']),
      promptTokens: jsonInt(json['promptTokens']),
      completionTokens: jsonInt(json['completionTokens']),
      createdAt: jsonDate(json['createdAt']),
    );
  }
}

/// 管理后台 AI 聊天详情模型
class AdminAiChatDetail {
  const AdminAiChatDetail({required this.session, required this.messages});

  final AdminAiChatSessionItem session;
  final List<AdminAiChatMessageItem> messages;

  /// 从 JSON 创建实例
  factory AdminAiChatDetail.fromJson(Map<String, dynamic> json) {
    return AdminAiChatDetail(
      session: AdminAiChatSessionItem.fromJson(
        (json['session'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      messages: (json['messages'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => AdminAiChatMessageItem.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

/// 管理后台 AI 聊天查询参数
class AdminAiChatQuery {
  const AdminAiChatQuery({
    this.query = '',
    this.userId = '',
    this.page = 0,
    this.size = 50,
  });

  final String query;
  final String userId;
  final int page;
  final int size;

  @override
  bool operator ==(Object other) {
    return other is AdminAiChatQuery &&
        other.query == query &&
        other.userId == userId &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(query, userId, page, size);
}
