// 评论相关数据模型
// 包含评论项、管理后台评论等

import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'helpers.dart';
import 'json_converters.dart';

part 'comment_models.g.dart';

/// 评论项模型
/// 保留手写 fromJson：需要从嵌套的 author 对象提取字段
class CommentItem {
  const CommentItem({
    required this.id,
    required this.contentId,
    required this.contentTitle,
    required this.body,
    required this.authorId,
    required this.authorNickname,
    required this.createdAt,
    this.authorAvatarUrl,
    this.auditStatus,
  });

  final String id;
  final String contentId;
  final String contentTitle;
  final String body;
  final String authorId;
  final String authorNickname;
  final DateTime createdAt;
  final String? authorAvatarUrl;
  final String? auditStatus;

  /// 是否被屏蔽
  bool get blocked => auditStatus == 'BLOCKED';

  /// 从 JSON 创建实例
  factory CommentItem.fromJson(Map<String, dynamic> json) {
    final author = (json['author'] as Map? ?? const {}).cast<String, dynamic>();
    final nickname = jsonString(author['nickname']);
    return CommentItem(
      id: jsonString(json['id']),
      contentId: jsonString(json['contentId']),
      contentTitle: jsonString(json['contentTitle']),
      body: jsonString(json['body']),
      authorId: jsonString(author['id']),
      authorNickname: nickname.isEmpty ? '用户' : nickname,
      createdAt: jsonDate(json['createdAt']),
      authorAvatarUrl: jsonNullableString(author['avatarUrl']),
      auditStatus: jsonNullableString(json['auditStatus']),
    );
  }
}

/// 管理后台评论项模型
@JsonSerializable()
class AdminCommentItem {
  const AdminCommentItem({
    required this.id,
    required this.contentId,
    required this.contentTitle,
    required this.userId,
    required this.userNickname,
    required this.userEmail,
    required this.status,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
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
  @AdminCommentStatusJsonConverter()
  final AdminCommentStatus status;
  @SafeStringJsonConverter()
  final String body;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;
  @SafeDateTimeJsonConverter()
  final DateTime updatedAt;

  /// 是否已删除
  bool get deleted => status == AdminCommentStatus.deleted;

  factory AdminCommentItem.fromJson(Map<String, dynamic> json) =>
      _$AdminCommentItemFromJson(json);

  Map<String, dynamic> toJson() => _$AdminCommentItemToJson(this);
}

/// 管理后台评论查询参数
class AdminCommentQuery {
  const AdminCommentQuery({
    this.status,
    this.contentId = '',
    this.userId = '',
    this.page = 0,
    this.size = 50,
  });

  final AdminCommentStatus? status;
  final String contentId;
  final String userId;
  final int page;
  final int size;

  AdminCommentQuery copyWith({
    AdminCommentStatus? status,
    bool clearStatus = false,
    String? contentId,
    String? userId,
    int? page,
    int? size,
  }) {
    return AdminCommentQuery(
      status: clearStatus ? null : (status ?? this.status),
      contentId: contentId ?? this.contentId,
      userId: userId ?? this.userId,
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AdminCommentQuery &&
        other.status == status &&
        other.contentId == contentId &&
        other.userId == userId &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(status, contentId, userId, page, size);
}
