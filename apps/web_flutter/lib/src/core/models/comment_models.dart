// 评论相关数据模型
// 包含评论项、管理后台评论等

import 'enums.dart';
import 'helpers.dart';

/// 评论项模型
class CommentItem {
  const CommentItem({
    required this.id,
    required this.contentId,
    required this.contentTitle,
    required this.body,
    required this.authorId,
    required this.authorNickname,
    required this.createdAt,
    this.auditStatus,
  });

  final String id;
  final String contentId;
  final String contentTitle;
  final String body;
  final String authorId;
  final String authorNickname;
  final DateTime createdAt;
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
      auditStatus: jsonNullableString(json['auditStatus']),
    );
  }
}

/// 管理后台评论项模型
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

  final String id;
  final String contentId;
  final String contentTitle;
  final String userId;
  final String userNickname;
  final String userEmail;
  final AdminCommentStatus status;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 是否已删除
  bool get deleted => status == AdminCommentStatus.deleted;

  /// 从 JSON 创建实例
  factory AdminCommentItem.fromJson(Map<String, dynamic> json) {
    return AdminCommentItem(
      id: jsonString(json['id']),
      contentId: jsonString(json['contentId']),
      contentTitle: jsonString(json['contentTitle']),
      userId: jsonString(json['userId']),
      userNickname: jsonString(json['userNickname']),
      userEmail: jsonString(json['userEmail']),
      status: AdminCommentStatus.fromApi(jsonString(json['status'])),
      body: jsonString(json['body']),
      createdAt: jsonDate(json['createdAt']),
      updatedAt: jsonDate(json['updatedAt']),
    );
  }
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
