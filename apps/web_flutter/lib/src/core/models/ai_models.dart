// AI 相关数据模型
// 包含 AI 配额、聊天回复、会话、消息等

import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'json_converters.dart';

part 'ai_models.g.dart';

/// AI 配额模型
@JsonSerializable()
class AiQuota {
  const AiQuota({required this.dailyLimit, required this.used});

  @SafeIntJsonConverter()
  final int dailyLimit;
  @SafeIntJsonConverter()
  final int used;

  /// 剩余配额
  int get remaining => dailyLimit - used;

  factory AiQuota.fromJson(Map<String, dynamic> json) =>
      _$AiQuotaFromJson(json);

  Map<String, dynamic> toJson() => _$AiQuotaToJson(this);
}

/// AI 聊天回复模型
@JsonSerializable()
class AiChatReply {
  const AiChatReply({
    required this.sessionId,
    required this.answer,
    required this.remainingQuestions,
    required this.remainingMessages,
  });

  @SafeStringJsonConverter()
  final String sessionId;
  @SafeStringJsonConverter()
  final String answer;
  @SafeIntJsonConverter()
  final int remainingQuestions;
  @SafeIntJsonConverter()
  final int remainingMessages;

  factory AiChatReply.fromJson(Map<String, dynamic> json) =>
      _$AiChatReplyFromJson(json);

  Map<String, dynamic> toJson() => _$AiChatReplyToJson(this);
}

/// AI 会话项模型
@JsonSerializable()
class AiSessionItem {
  const AiSessionItem({
    required this.id,
    required this.title,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String title;
  @SafeIntJsonConverter()
  final int messageCount;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;
  @SafeDateTimeJsonConverter()
  final DateTime updatedAt;

  factory AiSessionItem.fromJson(Map<String, dynamic> json) =>
      _$AiSessionItemFromJson(json);

  Map<String, dynamic> toJson() => _$AiSessionItemToJson(this);
}

/// AI 消息项模型
@JsonSerializable()
class AiMessageItem {
  const AiMessageItem({
    required this.id,
    required this.role,
    required this.content,
    this.auditStatus,
    required this.createdAt,
  });

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String role;
  @SafeStringJsonConverter()
  final String content;
  final String? auditStatus;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;

  factory AiMessageItem.fromJson(Map<String, dynamic> json) =>
      _$AiMessageItemFromJson(json);

  Map<String, dynamic> toJson() => _$AiMessageItemToJson(this);
}

/// 管理后台 AI 聊天会话项模型
@JsonSerializable()
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

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String userId;
  @SafeStringJsonConverter()
  final String userNickname;
  @SafeStringJsonConverter()
  final String userEmail;
  @SafeStringJsonConverter()
  final String title;
  @SafeIntJsonConverter()
  final int messageCount;
  @SafeStringJsonConverter()
  final String lastMessage;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;
  @SafeDateTimeJsonConverter()
  final DateTime updatedAt;

  factory AdminAiChatSessionItem.fromJson(Map<String, dynamic> json) =>
      _$AdminAiChatSessionItemFromJson(json);

  Map<String, dynamic> toJson() => _$AdminAiChatSessionItemToJson(this);
}

/// 管理后台 AI 聊天消息项模型
@JsonSerializable()
class AdminAiChatMessageItem {
  const AdminAiChatMessageItem({
    required this.id,
    required this.role,
    required this.content,
    required this.toolName,
    required this.promptTokens,
    required this.completionTokens,
    this.auditStatus,
    this.auditReason,
    required this.createdAt,
  });

  @SafeStringJsonConverter()
  final String id;
  @AiChatMessageRoleJsonConverter()
  final AiChatMessageRole role;
  @SafeStringJsonConverter()
  final String content;
  @SafeStringJsonConverter()
  final String toolName;
  @SafeIntJsonConverter()
  final int promptTokens;
  @SafeIntJsonConverter()
  final int completionTokens;
  final String? auditStatus;
  final String? auditReason;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;

  factory AdminAiChatMessageItem.fromJson(Map<String, dynamic> json) =>
      _$AdminAiChatMessageItemFromJson(json);

  Map<String, dynamic> toJson() => _$AdminAiChatMessageItemToJson(this);
}

/// 管理后台 AI 聊天详情模型
/// 保留手写 fromJson：包含防御性类型转换逻辑
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
