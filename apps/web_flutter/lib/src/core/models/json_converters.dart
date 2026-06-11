// 自定义 JSON 转换器
// 为 json_serializable 提供安全的类型转换，复用现有 helpers.dart 的逻辑

import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';

// --- 枚举转换器（每个枚举一个，避免 source_gen 解析泛型函数参数的问题）---

class ContentTypeJsonConverter implements JsonConverter<ContentType, String> {
  const ContentTypeJsonConverter();

  @override
  ContentType fromJson(String json) => ContentType.fromApi(json);

  @override
  String toJson(ContentType object) => object.apiValue;
}

class ContentStatusJsonConverter
    implements JsonConverter<ContentStatus, String> {
  const ContentStatusJsonConverter();

  @override
  ContentStatus fromJson(String json) => ContentStatus.fromApi(json);

  @override
  String toJson(ContentStatus object) => object.apiValue;
}

class MediaAssetTypeJsonConverter
    implements JsonConverter<MediaAssetType, String> {
  const MediaAssetTypeJsonConverter();

  @override
  MediaAssetType fromJson(String json) => MediaAssetType.fromApi(json);

  @override
  String toJson(MediaAssetType object) => object.apiValue;
}

class AdminCommentStatusJsonConverter
    implements JsonConverter<AdminCommentStatus, String> {
  const AdminCommentStatusJsonConverter();

  @override
  AdminCommentStatus fromJson(String json) => AdminCommentStatus.fromApi(json);

  @override
  String toJson(AdminCommentStatus object) => object.apiValue;
}

class AdminUserRoleJsonConverter
    implements JsonConverter<AdminUserRole, String> {
  const AdminUserRoleJsonConverter();

  @override
  AdminUserRole fromJson(String json) => AdminUserRole.fromApi(json);

  @override
  String toJson(AdminUserRole object) => object.apiValue;
}

class AdminUserStatusJsonConverter
    implements JsonConverter<AdminUserStatus, String> {
  const AdminUserStatusJsonConverter();

  @override
  AdminUserStatus fromJson(String json) => AdminUserStatus.fromApi(json);

  @override
  String toJson(AdminUserStatus object) => object.apiValue;
}

class KnowledgeSourceTypeJsonConverter
    implements JsonConverter<KnowledgeSourceType, String> {
  const KnowledgeSourceTypeJsonConverter();

  @override
  KnowledgeSourceType fromJson(String json) => KnowledgeSourceType.fromApi(json);

  @override
  String toJson(KnowledgeSourceType object) => object.apiValue;
}

class AiChatMessageRoleJsonConverter
    implements JsonConverter<AiChatMessageRole, String> {
  const AiChatMessageRoleJsonConverter();

  @override
  AiChatMessageRole fromJson(String json) => AiChatMessageRole.fromApi(json);

  @override
  String toJson(AiChatMessageRole object) => object.name.toUpperCase();
}

// --- 安全类型转换器 ---

/// 安全字符串转换：null → ''
class SafeStringJsonConverter implements JsonConverter<String, Object?> {
  const SafeStringJsonConverter();

  @override
  String fromJson(Object? json) => json?.toString() ?? '';

  @override
  Object? toJson(String object) => object;
}

/// 可空字符串转换：'' → null
class NullableStringJsonConverter implements JsonConverter<String?, Object?> {
  const NullableStringJsonConverter();

  @override
  String? fromJson(Object? json) {
    if (json == null) return null;
    final text = json.toString();
    return text.isEmpty ? null : text;
  }

  @override
  Object? toJson(String? object) => object;
}

/// 安全 int 转换：null → 0，解析失败 → 0
class SafeIntJsonConverter implements JsonConverter<int, Object?> {
  const SafeIntJsonConverter();

  @override
  int fromJson(Object? json) {
    if (json is num) return json.toInt();
    if (json is String) return int.tryParse(json) ?? 0;
    return 0;
  }

  @override
  Object? toJson(int object) => object;
}

/// 安全字符串列表转换：null → []，过滤空字符串
class SafeStringListJsonConverter
    implements JsonConverter<List<String>, Object?> {
  const SafeStringListJsonConverter();

  @override
  List<String> fromJson(Object? json) {
    if (json is List) {
      return json
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  @override
  Object? toJson(List<String> object) => object;
}

/// 安全 DateTime 转换：null → epoch，解析失败 → epoch
class SafeDateTimeJsonConverter implements JsonConverter<DateTime, Object?> {
  const SafeDateTimeJsonConverter();

  @override
  DateTime fromJson(Object? json) {
    if (json is String) {
      return DateTime.tryParse(json)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Object? toJson(DateTime object) => object.toUtc().toIso8601String();
}

/// 可空 DateTime 转换：null → null，解析失败 → null
class NullableSafeDateTimeJsonConverter
    implements JsonConverter<DateTime?, Object?> {
  const NullableSafeDateTimeJsonConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json is String) {
      return DateTime.tryParse(json)?.toLocal();
    }
    return null;
  }

  @override
  Object? toJson(DateTime? object) => object?.toUtc().toIso8601String();
}
