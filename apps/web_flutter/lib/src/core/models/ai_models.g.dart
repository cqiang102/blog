// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiQuota _$AiQuotaFromJson(Map<String, dynamic> json) => AiQuota(
  dailyLimit: const SafeIntJsonConverter().fromJson(json['dailyLimit']),
  used: const SafeIntJsonConverter().fromJson(json['used']),
);

Map<String, dynamic> _$AiQuotaToJson(AiQuota instance) => <String, dynamic>{
  'dailyLimit': const SafeIntJsonConverter().toJson(instance.dailyLimit),
  'used': const SafeIntJsonConverter().toJson(instance.used),
};

AiChatReply _$AiChatReplyFromJson(Map<String, dynamic> json) => AiChatReply(
  sessionId: const SafeStringJsonConverter().fromJson(json['sessionId']),
  answer: const SafeStringJsonConverter().fromJson(json['answer']),
  remainingQuestions: const SafeIntJsonConverter().fromJson(
    json['remainingQuestions'],
  ),
  remainingMessages: const SafeIntJsonConverter().fromJson(
    json['remainingMessages'],
  ),
);

Map<String, dynamic> _$AiChatReplyToJson(AiChatReply instance) =>
    <String, dynamic>{
      'sessionId': const SafeStringJsonConverter().toJson(instance.sessionId),
      'answer': const SafeStringJsonConverter().toJson(instance.answer),
      'remainingQuestions': const SafeIntJsonConverter().toJson(
        instance.remainingQuestions,
      ),
      'remainingMessages': const SafeIntJsonConverter().toJson(
        instance.remainingMessages,
      ),
    };

AiSessionItem _$AiSessionItemFromJson(Map<String, dynamic> json) =>
    AiSessionItem(
      id: const SafeStringJsonConverter().fromJson(json['id']),
      title: const SafeStringJsonConverter().fromJson(json['title']),
      messageCount: const SafeIntJsonConverter().fromJson(json['messageCount']),
      createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
      updatedAt: const SafeDateTimeJsonConverter().fromJson(json['updatedAt']),
    );

Map<String, dynamic> _$AiSessionItemToJson(
  AiSessionItem instance,
) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'title': const SafeStringJsonConverter().toJson(instance.title),
  'messageCount': const SafeIntJsonConverter().toJson(instance.messageCount),
  'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
  'updatedAt': const SafeDateTimeJsonConverter().toJson(instance.updatedAt),
};

AiMessageItem _$AiMessageItemFromJson(Map<String, dynamic> json) =>
    AiMessageItem(
      id: const SafeStringJsonConverter().fromJson(json['id']),
      role: const SafeStringJsonConverter().fromJson(json['role']),
      content: const SafeStringJsonConverter().fromJson(json['content']),
      auditStatus: json['auditStatus'] as String?,
      createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
    );

Map<String, dynamic> _$AiMessageItemToJson(AiMessageItem instance) =>
    <String, dynamic>{
      'id': const SafeStringJsonConverter().toJson(instance.id),
      'role': const SafeStringJsonConverter().toJson(instance.role),
      'content': const SafeStringJsonConverter().toJson(instance.content),
      'auditStatus': instance.auditStatus,
      'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
    };

AdminAiChatSessionItem _$AdminAiChatSessionItemFromJson(
  Map<String, dynamic> json,
) => AdminAiChatSessionItem(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  userId: const SafeStringJsonConverter().fromJson(json['userId']),
  userNickname: const SafeStringJsonConverter().fromJson(json['userNickname']),
  userEmail: const SafeStringJsonConverter().fromJson(json['userEmail']),
  title: const SafeStringJsonConverter().fromJson(json['title']),
  messageCount: const SafeIntJsonConverter().fromJson(json['messageCount']),
  lastMessage: const SafeStringJsonConverter().fromJson(json['lastMessage']),
  createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
  updatedAt: const SafeDateTimeJsonConverter().fromJson(json['updatedAt']),
);

Map<String, dynamic> _$AdminAiChatSessionItemToJson(
  AdminAiChatSessionItem instance,
) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'userId': const SafeStringJsonConverter().toJson(instance.userId),
  'userNickname': const SafeStringJsonConverter().toJson(instance.userNickname),
  'userEmail': const SafeStringJsonConverter().toJson(instance.userEmail),
  'title': const SafeStringJsonConverter().toJson(instance.title),
  'messageCount': const SafeIntJsonConverter().toJson(instance.messageCount),
  'lastMessage': const SafeStringJsonConverter().toJson(instance.lastMessage),
  'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
  'updatedAt': const SafeDateTimeJsonConverter().toJson(instance.updatedAt),
};

AdminAiChatMessageItem _$AdminAiChatMessageItemFromJson(
  Map<String, dynamic> json,
) => AdminAiChatMessageItem(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  role: const AiChatMessageRoleJsonConverter().fromJson(json['role'] as String),
  content: const SafeStringJsonConverter().fromJson(json['content']),
  toolName: const SafeStringJsonConverter().fromJson(json['toolName']),
  promptTokens: const SafeIntJsonConverter().fromJson(json['promptTokens']),
  completionTokens: const SafeIntJsonConverter().fromJson(
    json['completionTokens'],
  ),
  auditStatus: json['auditStatus'] as String?,
  auditReason: json['auditReason'] as String?,
  createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
);

Map<String, dynamic> _$AdminAiChatMessageItemToJson(
  AdminAiChatMessageItem instance,
) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'role': const AiChatMessageRoleJsonConverter().toJson(instance.role),
  'content': const SafeStringJsonConverter().toJson(instance.content),
  'toolName': const SafeStringJsonConverter().toJson(instance.toolName),
  'promptTokens': const SafeIntJsonConverter().toJson(instance.promptTokens),
  'completionTokens': const SafeIntJsonConverter().toJson(
    instance.completionTokens,
  ),
  'auditStatus': instance.auditStatus,
  'auditReason': instance.auditReason,
  'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
};
