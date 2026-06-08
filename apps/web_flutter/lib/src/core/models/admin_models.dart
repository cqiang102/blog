// 管理后台相关数据模型
// 包含点赞、浏览记录、用户管理、仪表盘等

import 'enums.dart';
import 'helpers.dart';

/// 管理后台点赞项模型
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

  final String id;
  final String contentId;
  final String contentTitle;
  final String userId;
  final String userNickname;
  final String userEmail;
  final DateTime createdAt;

  /// 从 JSON 创建实例
  factory AdminLikeItem.fromJson(Map<String, dynamic> json) {
    return AdminLikeItem(
      id: jsonString(json['id']),
      contentId: jsonString(json['contentId']),
      contentTitle: jsonString(json['contentTitle']),
      userId: jsonString(json['userId']),
      userNickname: jsonString(json['userNickname']),
      userEmail: jsonString(json['userEmail']),
      createdAt: jsonDate(json['createdAt']),
    );
  }
}

/// 管理后台浏览记录项模型
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

  final String id;
  final String contentId;
  final String contentTitle;
  final String userId;
  final String userNickname;
  final String userEmail;
  final String anonymousId;
  final String ipHash;
  final String userAgent;
  final DateTime createdAt;

  /// 是否匿名用户
  bool get anonymous => userId.isEmpty;

  /// 从 JSON 创建实例
  factory AdminViewRecordItem.fromJson(Map<String, dynamic> json) {
    return AdminViewRecordItem(
      id: jsonString(json['id']),
      contentId: jsonString(json['contentId']),
      contentTitle: jsonString(json['contentTitle']),
      userId: jsonString(json['userId']),
      userNickname: jsonString(json['userNickname']),
      userEmail: jsonString(json['userEmail']),
      anonymousId: jsonString(json['anonymousId']),
      ipHash: jsonString(json['ipHash']),
      userAgent: jsonString(json['userAgent']),
      createdAt: jsonDate(json['createdAt']),
    );
  }
}

/// 管理后台用户项模型
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

  final String id;
  final String email;
  final String nickname;
  final String avatarUrl;
  final String bio;
  final String blogUrl;
  final AdminUserRole role;
  final AdminUserStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 是否已禁用
  bool get disabled => status == AdminUserStatus.disabled;

  /// 从 JSON 创建实例
  factory AdminUserItem.fromJson(Map<String, dynamic> json) {
    return AdminUserItem(
      id: jsonString(json['id']),
      email: jsonString(json['email']),
      nickname: jsonString(json['nickname']),
      avatarUrl: jsonString(json['avatarUrl']),
      bio: jsonString(json['bio']),
      blogUrl: jsonString(json['blogUrl']),
      role: AdminUserRole.fromApi(jsonString(json['role'])),
      status: AdminUserStatus.fromApi(jsonString(json['status'])),
      createdAt: jsonDate(json['createdAt']),
      updatedAt: jsonDate(json['updatedAt']),
    );
  }
}

/// 管理后台用户编辑草稿模型
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

  final int contents;
  final int media;
  final int friends;
  final int users;
  final int comments;
  final int likes;
  final int views;
  final int aiChats;
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

  /// 从 JSON 创建实例
  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    return AdminDashboard(
      contents: jsonInt(json['contents']),
      media: jsonInt(json['media']),
      friends: jsonInt(json['friends']),
      users: jsonInt(json['users']),
      comments: jsonInt(json['comments']),
      likes: jsonInt(json['likes']),
      views: jsonInt(json['views']),
      aiChats: jsonInt(json['aiChats']),
      knowledgeDocs: jsonInt(json['knowledgeDocs']),
    );
  }
}

/// 审计日志项模型
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

  final String id;
  final String? actorUserId;
  final String? actorNickname;
  final String action;
  final String resourceType;
  final String? resourceId;
  final String? detail;
  final DateTime createdAt;

  /// 从 JSON 创建实例
  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: jsonString(json['id']),
      actorUserId: jsonNullableString(json['actorUserId']),
      actorNickname: jsonNullableString(json['actorNickname']),
      action: jsonString(json['action']),
      resourceType: jsonString(json['resourceType']),
      resourceId: jsonNullableString(json['resourceId']),
      detail: jsonNullableString(json['detail']),
      createdAt: jsonDate(json['createdAt']),
    );
  }
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
class UserActivity {
  const UserActivity({
    required this.id,
    required this.type,
    required this.contentId,
    required this.title,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String contentId;
  final String title;
  final DateTime createdAt;

  /// 从 JSON 创建实例
  factory UserActivity.fromJson(Map<String, dynamic> json) {
    return UserActivity(
      id: jsonString(json['id']),
      type: jsonString(json['type']),
      contentId: jsonString(json['contentId']),
      title: jsonString(json['title']),
      createdAt: jsonDate(json['createdAt']),
    );
  }
}
