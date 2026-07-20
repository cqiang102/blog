// 管理后台相关数据模型
// 包含点赞、浏览记录、用户管理、仪表盘等

import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'json_converters.dart';

part 'admin_models.g.dart';

/// 管理后台点赞项模型
@JsonSerializable()
class AdminLikeItem {
  const AdminLikeItem({
    required this.id,
    required this.contentId,
    required this.contentTitle,
    required this.userId,
    required this.userNickname,
    required this.userEmail,
    required this.createdAt,
  });

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String contentId;
  @SafeStringJsonConverter()
  final String contentTitle;
  @SafeStringJsonConverter()
  final String userId;
  @SafeStringJsonConverter()
  final String userNickname;
  @SafeStringJsonConverter()
  final String userEmail;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;

  factory AdminLikeItem.fromJson(Map<String, dynamic> json) =>
      _$AdminLikeItemFromJson(json);

  Map<String, dynamic> toJson() => _$AdminLikeItemToJson(this);
}

/// 管理后台浏览记录项模型
@JsonSerializable()
class AdminViewRecordItem {
  const AdminViewRecordItem({
    required this.id,
    required this.contentId,
    required this.contentTitle,
    required this.userId,
    required this.userNickname,
    required this.userEmail,
    required this.anonymousId,
    required this.ipHash,
    required this.userAgent,
    required this.createdAt,
  });

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String contentId;
  @SafeStringJsonConverter()
  final String contentTitle;
  @SafeStringJsonConverter()
  final String userId;
  @SafeStringJsonConverter()
  final String userNickname;
  @SafeStringJsonConverter()
  final String userEmail;
  @SafeStringJsonConverter()
  final String anonymousId;
  @SafeStringJsonConverter()
  final String ipHash;
  @SafeStringJsonConverter()
  final String userAgent;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;

  /// 是否匿名用户
  bool get anonymous => userId.isEmpty;

  factory AdminViewRecordItem.fromJson(Map<String, dynamic> json) =>
      _$AdminViewRecordItemFromJson(json);

  Map<String, dynamic> toJson() => _$AdminViewRecordItemToJson(this);
}

/// 管理后台用户项模型
@JsonSerializable()
class AdminUserItem {
  const AdminUserItem({
    required this.id,
    required this.email,
    required this.nickname,
    required this.avatarUrl,
    required this.bio,
    required this.blogUrl,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String email;
  @SafeStringJsonConverter()
  final String nickname;
  @SafeStringJsonConverter()
  final String avatarUrl;
  @SafeStringJsonConverter()
  final String bio;
  @SafeStringJsonConverter()
  final String blogUrl;
  @AdminUserRoleJsonConverter()
  final AdminUserRole role;
  @AdminUserStatusJsonConverter()
  final AdminUserStatus status;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;
  @SafeDateTimeJsonConverter()
  final DateTime updatedAt;

  /// 是否已禁用
  bool get disabled => status == AdminUserStatus.disabled;

  factory AdminUserItem.fromJson(Map<String, dynamic> json) =>
      _$AdminUserItemFromJson(json);

  Map<String, dynamic> toJson() => _$AdminUserItemToJson(this);
}

/// 管理后台用户编辑草稿模型
/// 保留手写 toJson：包含 .trim() 调用
class AdminUserDraft {
  const AdminUserDraft({
    required this.email,
    required this.nickname,
    required this.avatarUrl,
    required this.bio,
    required this.blogUrl,
    required this.role,
    required this.status,
  });

  final String email;
  final String nickname;
  final String avatarUrl;
  final String bio;
  final String blogUrl;
  final AdminUserRole role;
  final AdminUserStatus status;

  /// 从 AdminUserItem 创建草稿
  factory AdminUserDraft.fromItem(AdminUserItem item) {
    return AdminUserDraft(
      email: item.email,
      nickname: item.nickname,
      avatarUrl: item.avatarUrl,
      bio: item.bio,
      blogUrl: item.blogUrl,
      role: item.role,
      status: item.status,
    );
  }

  /// 转换为 JSON Map
  Map<String, Object?> toJson() {
    return {
      'email': email.trim(),
      'nickname': nickname.trim(),
      'avatarUrl': avatarUrl.trim(),
      'bio': bio.trim(),
      'blogUrl': blogUrl.trim(),
      'role': role.apiValue,
      'status': status.apiValue,
    };
  }
}

/// 管理后台记录查询参数
class AdminRecordQuery {
  const AdminRecordQuery({
    this.contentId = '',
    this.userId = '',
    this.page = 0,
    this.size = 50,
  });

  final String contentId;
  final String userId;
  final int page;
  final int size;

  AdminRecordQuery copyWith({
    String? contentId,
    String? userId,
    int? page,
    int? size,
  }) {
    return AdminRecordQuery(
      contentId: contentId ?? this.contentId,
      userId: userId ?? this.userId,
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AdminRecordQuery &&
        other.contentId == contentId &&
        other.userId == userId &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(contentId, userId, page, size);
}

/// 管理后台用户查询参数
class AdminUserQuery {
  const AdminUserQuery({
    this.query = '',
    this.role,
    this.status,
    this.page = 0,
    this.size = 50,
  });

  final String query;
  final AdminUserRole? role;
  final AdminUserStatus? status;
  final int page;
  final int size;

  AdminUserQuery copyWith({
    String? query,
    AdminUserRole? role,
    bool clearRole = false,
    AdminUserStatus? status,
    bool clearStatus = false,
    int? page,
    int? size,
  }) {
    return AdminUserQuery(
      query: query ?? this.query,
      role: clearRole ? null : (role ?? this.role),
      status: clearStatus ? null : (status ?? this.status),
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AdminUserQuery &&
        other.query == query &&
        other.role == role &&
        other.status == status &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(query, role, status, page, size);
}

/// 管理后台指标模型
class AdminMetric {
  const AdminMetric(this.label, this.value);

  final String label;
  final String value;
}

/// 管理后台仪表盘模型
@JsonSerializable()
class AdminDashboard {
  const AdminDashboard({
    required this.contents,
    required this.media,
    required this.friends,
    required this.users,
    required this.comments,
    required this.likes,
    required this.views,
    required this.aiChats,
    required this.knowledgeDocs,
  });

  @SafeIntJsonConverter()
  final int contents;
  @SafeIntJsonConverter()
  final int media;
  @SafeIntJsonConverter()
  final int friends;
  @SafeIntJsonConverter()
  final int users;
  @SafeIntJsonConverter()
  final int comments;
  @SafeIntJsonConverter()
  final int likes;
  @SafeIntJsonConverter()
  final int views;
  @SafeIntJsonConverter()
  final int aiChats;
  @SafeIntJsonConverter()
  final int knowledgeDocs;

  /// 获取指标列表
  List<AdminMetric> get metrics {
    return [
      AdminMetric('内容', contents.toString()),
      AdminMetric('媒体', media.toString()),
      AdminMetric('朋友', friends.toString()),
      AdminMetric('用户', users.toString()),
      AdminMetric('评论', comments.toString()),
      AdminMetric('点赞', likes.toString()),
      AdminMetric('浏览', views.toString()),
      AdminMetric('AI 会话', aiChats.toString()),
      AdminMetric('知识库', knowledgeDocs.toString()),
    ];
  }

  factory AdminDashboard.fromJson(Map<String, dynamic> json) =>
      _$AdminDashboardFromJson(json);

  Map<String, dynamic> toJson() => _$AdminDashboardToJson(this);
}

/// 审计日志项模型
@JsonSerializable()
class AuditLogItem {
  const AuditLogItem({
    required this.id,
    required this.action,
    required this.resourceType,
    this.actorUserId,
    this.actorNickname,
    this.resourceId,
    this.detail,
    required this.createdAt,
  });

  @SafeStringJsonConverter()
  final String id;
  @NullableStringJsonConverter()
  final String? actorUserId;
  @NullableStringJsonConverter()
  final String? actorNickname;
  @SafeStringJsonConverter()
  final String action;
  @SafeStringJsonConverter()
  final String resourceType;
  @NullableStringJsonConverter()
  final String? resourceId;
  @NullableStringJsonConverter()
  final String? detail;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;

  factory AuditLogItem.fromJson(Map<String, dynamic> json) =>
      _$AuditLogItemFromJson(json);

  Map<String, dynamic> toJson() => _$AuditLogItemToJson(this);
}

/// 审计日志查询参数
class AuditLogQuery {
  const AuditLogQuery({
    this.action,
    this.resourceType,
    this.page = 0,
    this.size = 50,
  });

  final String? action;
  final String? resourceType;
  final int page;
  final int size;

  AuditLogQuery copyWith({
    String? action,
    bool clearAction = false,
    String? resourceType,
    bool clearResourceType = false,
    int? page,
    int? size,
  }) {
    return AuditLogQuery(
      action: clearAction ? null : (action ?? this.action),
      resourceType: clearResourceType
          ? null
          : (resourceType ?? this.resourceType),
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditLogQuery &&
          runtimeType == other.runtimeType &&
          action == other.action &&
          resourceType == other.resourceType &&
          page == other.page &&
          size == other.size;

  @override
  int get hashCode => Object.hash(action, resourceType, page, size);
}

/// 用户活动记录模型
@JsonSerializable()
class UserActivity {
  const UserActivity({
    required this.id,
    required this.type,
    required this.contentId,
    required this.title,
    required this.createdAt,
  });

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String type;
  @SafeStringJsonConverter()
  final String contentId;
  @SafeStringJsonConverter()
  final String title;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;

  factory UserActivity.fromJson(Map<String, dynamic> json) =>
      _$UserActivityFromJson(json);

  Map<String, dynamic> toJson() => _$UserActivityToJson(this);
}
