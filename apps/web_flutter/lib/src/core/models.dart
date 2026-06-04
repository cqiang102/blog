/// 数据模型定义
/// 包含所有枚举类型、数据模型类及其 JSON 序列化/反序列化逻辑
library;

/// 内容类型枚举
enum ContentType {
  /// 纯文本
  text,
  /// 图文
  article,
  /// 图片
  image,
  /// 视频
  video;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      ContentType.text => 'TEXT',
      ContentType.article => 'ARTICLE',
      ContentType.image => 'IMAGE',
      ContentType.video => 'VIDEO',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      ContentType.text => '文本',
      ContentType.article => '图文',
      ContentType.image => '图片',
      ContentType.video => '视频',
    };
  }

  /// 从 API 字符串值转换为枚举
  /// [value] API 返回的字符串值
  /// 返回值：对应的 ContentType 枚举
  static ContentType fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'TEXT' => ContentType.text,
      'IMAGE' => ContentType.image,
      'VIDEO' => ContentType.video,
      _ => ContentType.article,
    };
  }
}

/// 内容状态枚举
enum ContentStatus {
  /// 草稿
  draft,
  /// 已发布
  published,
  /// 已归档
  archived;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      ContentStatus.draft => 'DRAFT',
      ContentStatus.published => 'PUBLISHED',
      ContentStatus.archived => 'ARCHIVED',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      ContentStatus.draft => '草稿',
      ContentStatus.published => '已发布',
      ContentStatus.archived => '已归档',
    };
  }

  /// 从 API 字符串值转换为枚举
  static ContentStatus fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'PUBLISHED' => ContentStatus.published,
      'ARCHIVED' => ContentStatus.archived,
      _ => ContentStatus.draft,
    };
  }
}

/// 媒体资源类型枚举
enum MediaAssetType {
  /// 图片
  image,
  /// 视频
  video,
  /// 文件
  file;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      MediaAssetType.image => 'IMAGE',
      MediaAssetType.video => 'VIDEO',
      MediaAssetType.file => 'FILE',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      MediaAssetType.image => '图片',
      MediaAssetType.video => '视频',
      MediaAssetType.file => '文件',
    };
  }

  /// 从 API 字符串值转换为枚举
  static MediaAssetType fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'VIDEO' => MediaAssetType.video,
      'FILE' => MediaAssetType.file,
      _ => MediaAssetType.image,
    };
  }
}

/// 管理后台评论状态枚举
enum AdminCommentStatus {
  /// 可见
  visible,
  /// 已删除
  deleted;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      AdminCommentStatus.visible => 'VISIBLE',
      AdminCommentStatus.deleted => 'DELETED',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      AdminCommentStatus.visible => '可见',
      AdminCommentStatus.deleted => '已删除',
    };
  }

  /// 从 API 字符串值转换为枚举
  static AdminCommentStatus fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'DELETED' => AdminCommentStatus.deleted,
      _ => AdminCommentStatus.visible,
    };
  }
}

/// 管理后台用户角色枚举
enum AdminUserRole {
  /// 普通用户
  user,
  /// 管理员
  admin;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      AdminUserRole.user => 'USER',
      AdminUserRole.admin => 'ADMIN',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      AdminUserRole.user => '普通用户',
      AdminUserRole.admin => '管理员',
    };
  }

  /// 从 API 字符串值转换为枚举
  static AdminUserRole fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'ADMIN' => AdminUserRole.admin,
      _ => AdminUserRole.user,
    };
  }
}

/// 管理后台用户状态枚举
enum AdminUserStatus {
  /// 启用
  active,
  /// 禁用
  disabled;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      AdminUserStatus.active => 'ACTIVE',
      AdminUserStatus.disabled => 'DISABLED',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      AdminUserStatus.active => '启用',
      AdminUserStatus.disabled => '禁用',
    };
  }

  /// 从 API 字符串值转换为枚举
  static AdminUserStatus fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'DISABLED' => AdminUserStatus.disabled,
      _ => AdminUserStatus.active,
    };
  }
}

/// 知识库文档来源类型枚举
enum KnowledgeSourceType {
  /// 手动录入
  manual,
  /// 网页
  url,
  /// 文件
  file,
  /// 内容引用
  content;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      KnowledgeSourceType.manual => 'MANUAL',
      KnowledgeSourceType.url => 'URL',
      KnowledgeSourceType.file => 'FILE',
      KnowledgeSourceType.content => 'CONTENT',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      KnowledgeSourceType.manual => '手动录入',
      KnowledgeSourceType.url => '网页',
      KnowledgeSourceType.file => '文件',
      KnowledgeSourceType.content => '内容引用',
    };
  }

  /// 从 API 字符串值转换为枚举
  static KnowledgeSourceType fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'URL' => KnowledgeSourceType.url,
      'FILE' => KnowledgeSourceType.file,
      'CONTENT' => KnowledgeSourceType.content,
      _ => KnowledgeSourceType.manual,
    };
  }
}

/// 博客内容模型
/// 包含文章的基本信息、统计数据和媒体资源
class BlogContent {
  const BlogContent({
    required this.id,
    required this.title,
    required this.type,
    required this.summary,
    required this.coverUrl,
    required this.tags,
    required this.pinned,
    required this.likeCount,
    required this.publishedAt,
    this.slug = '',
    this.viewCount = 0,
    this.commentCount = 0,
    this.likedByCurrentUser = false,
    this.markdown = '',
    this.mediaUrls = const [],
  });

  final String id; // 内容 ID
  final String title; // 标题
  final String slug; // URL 别名
  final ContentType type; // 内容类型
  final String summary; // 摘要
  final String coverUrl; // 封面图 URL
  final List<String> tags; // 标签列表
  final bool pinned; // 是否置顶
  final int likeCount; // 点赞数
  final int viewCount; // 浏览数
  final int commentCount; // 评论数
  final bool likedByCurrentUser; // 当前用户是否已点赞
  final DateTime publishedAt; // 发布时间
  final String markdown; // Markdown 内容
  final List<String> mediaUrls; // 媒体资源 URL 列表

  /// 从列表摘要 JSON 创建实例
  factory BlogContent.fromSummaryJson(Map<String, dynamic> json) {
    return BlogContent(
      id: _string(json['id']),
      title: _string(json['title']),
      slug: _string(json['slug']),
      type: ContentType.fromApi(_string(json['type'])),
      summary: _string(json['summary']),
      coverUrl: _string(json['coverUrl']),
      tags: _stringList(json['tags']),
      pinned: json['pinned'] == true,
      likeCount: _int(json['likeCount']),
      publishedAt: _date(json['publishedAt']),
    );
  }

  /// 从详情 JSON 创建实例（包含完整内容和媒体）
  factory BlogContent.fromDetailJson(Map<String, dynamic> json) {
    final mediaUrls = _mediaUrls(json['mediaAssets']);
    final rawCoverUrl = _string(json['coverUrl']);
    return BlogContent(
      id: _string(json['id']),
      title: _string(json['title']),
      slug: _string(json['slug']),
      type: ContentType.fromApi(_string(json['type'])),
      summary: _string(json['summary']),
      coverUrl:
          rawCoverUrl.isNotEmpty
              ? rawCoverUrl
              : (mediaUrls.isEmpty ? '' : mediaUrls.first),
      tags: _stringList(json['tags']),
      pinned: json['pinned'] == true,
      likeCount: _int(json['likeCount']),
      viewCount: _int(json['viewCount']),
      commentCount: _int(json['commentCount']),
      likedByCurrentUser: json['likedByCurrentUser'] == true,
      publishedAt: _date(json['publishedAt']),
      markdown: _string(json['bodyMarkdown']),
      mediaUrls: mediaUrls,
    );
  }
}

/// 首页推荐内容模型
/// 包含置顶、最新和最热文章列表
class Recommendations {
  const Recommendations({
    required this.pinned,
    required this.latest,
    required this.mostLiked,
  });

  final List<BlogContent> pinned; // 置顶文章
  final List<BlogContent> latest; // 最新文章
  final List<BlogContent> mostLiked; // 最热文章

  /// 从 JSON 创建实例
  factory Recommendations.fromJson(Map<String, dynamic> json) {
    return Recommendations(
      pinned: _contentList(json['pinned']),
      latest: _contentList(json['latest']),
      mostLiked: _contentList(json['mostLiked']),
    );
  }
}

/// 分页结果泛型模型
/// [T] 数据项类型
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  final List<T> items; // 数据列表
  final int page; // 当前页码
  final int size; // 每页大小
  final int total; // 总记录数
}

/// 内容列表查询参数
class ContentListQuery {
  const ContentListQuery({
    this.query = '',
    this.tag,
    this.type,
    this.startDate,
    this.endDate,
    this.page = 0,
    this.size = 10,
  });

  final String query; // 搜索关键词
  final String? tag; // 标签筛选
  final ContentType? type; // 内容类型筛选
  final DateTime? startDate; // 开始日期
  final DateTime? endDate; // 结束日期
  final int page; // 页码
  final int size; // 每页大小

  @override
  bool operator ==(Object other) {
    return other is ContentListQuery &&
        other.query == query &&
        other.tag == tag &&
        other.type == type &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(query, tag, type, startDate, endDate, page, size);
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

  final AdminCommentStatus? status; // 评论状态筛选
  final String contentId; // 内容 ID 筛选
  final String userId; // 用户 ID 筛选
  final int page; // 页码
  final int size; // 每页大小

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

/// 管理后台记录查询参数
class AdminRecordQuery {
  const AdminRecordQuery({
    this.contentId = '',
    this.userId = '',
    this.page = 0,
    this.size = 50,
  });

  final String contentId; // 内容 ID 筛选
  final String userId; // 用户 ID 筛选
  final int page; // 页码
  final int size; // 每页大小

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

  final String query; // 搜索关键词
  final AdminUserRole? role; // 角色筛选
  final AdminUserStatus? status; // 状态筛选
  final int page; // 页码
  final int size; // 每页大小

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

/// 管理后台 AI 聊天查询参数
class AdminAiChatQuery {
  const AdminAiChatQuery({
    this.query = '',
    this.userId = '',
    this.page = 0,
    this.size = 50,
  });

  final String query; // 搜索关键词
  final String userId; // 用户 ID 筛选
  final int page; // 页码
  final int size; // 每页大小

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

/// 管理后台知识库文档查询参数
class AdminKnowledgeDocQuery {
  const AdminKnowledgeDocQuery({
    this.query = '',
    this.enabled,
    this.page = 0,
    this.size = 50,
  });

  final String query; // 搜索关键词
  final bool? enabled; // 启用状态筛选
  final int page; // 页码
  final int size; // 每页大小

  @override
  bool operator ==(Object other) {
    return other is AdminKnowledgeDocQuery &&
        other.query == query &&
        other.enabled == enabled &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(query, enabled, page, size);
}

/// 用户资料模型
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    required this.role,
    this.avatarUrl,
    this.bio,
    this.blogUrl,
    this.hasPassword = false,
  });

  final String id; // 用户 ID
  final String email; // 邮箱
  final String nickname; // 昵称
  final String role; // 角色
  final String? avatarUrl; // 头像 URL
  final String? bio; // 个人简介
  final String? blogUrl; // 博客链接
  final bool hasPassword; // 是否已设置密码

  /// 从 JSON 创建实例
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: _string(json['id']),
      email: _string(json['email']),
      nickname: _string(json['nickname']),
      role: _string(json['role']).isEmpty ? 'USER' : _string(json['role']),
      avatarUrl: _nullableString(json['avatarUrl']),
      bio: _nullableString(json['bio']),
      blogUrl: _nullableString(json['blogUrl']),
      hasPassword: json['hasPassword'] == true,
    );
  }

  /// 转换为 JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'role': role,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'blogUrl': blogUrl,
    };
  }
}

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

  final String id; // 评论 ID
  final String contentId; // 内容 ID
  final String contentTitle; // 内容标题
  final String body; // 评论内容
  final String authorId; // 作者 ID
  final String authorNickname; // 作者昵称
  final DateTime createdAt; // 创建时间
  final String? auditStatus; // 审核状态

  /// 是否被屏蔽
  bool get blocked => auditStatus == 'BLOCKED';

  /// 从 JSON 创建实例
  factory CommentItem.fromJson(Map<String, dynamic> json) {
    final author = (json['author'] as Map? ?? const {}).cast<String, dynamic>();
    final nickname = _string(author['nickname']);
    return CommentItem(
      id: _string(json['id']),
      contentId: _string(json['contentId']),
      contentTitle: _string(json['contentTitle']),
      body: _string(json['body']),
      authorId: _string(author['id']),
      authorNickname: nickname.isEmpty ? '用户' : nickname,
      createdAt: _date(json['createdAt']),
      auditStatus: _nullableString(json['auditStatus']),
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

  final String id; // 评论 ID
  final String contentId; // 内容 ID
  final String contentTitle; // 内容标题
  final String userId; // 用户 ID
  final String userNickname; // 用户昵称
  final String userEmail; // 用户邮箱
  final AdminCommentStatus status; // 评论状态
  final String body; // 评论内容
  final DateTime createdAt; // 创建时间
  final DateTime updatedAt; // 更新时间

  /// 是否已删除
  bool get deleted => status == AdminCommentStatus.deleted;

  /// 从 JSON 创建实例
  factory AdminCommentItem.fromJson(Map<String, dynamic> json) {
    return AdminCommentItem(
      id: _string(json['id']),
      contentId: _string(json['contentId']),
      contentTitle: _string(json['contentTitle']),
      userId: _string(json['userId']),
      userNickname: _string(json['userNickname']),
      userEmail: _string(json['userEmail']),
      status: AdminCommentStatus.fromApi(_string(json['status'])),
      body: _string(json['body']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

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

  final String id; // 点赞 ID
  final String contentId; // 内容 ID
  final String contentTitle; // 内容标题
  final String userId; // 用户 ID
  final String userNickname; // 用户昵称
  final String userEmail; // 用户邮箱
  final DateTime createdAt; // 创建时间

  /// 从 JSON 创建实例
  factory AdminLikeItem.fromJson(Map<String, dynamic> json) {
    return AdminLikeItem(
      id: _string(json['id']),
      contentId: _string(json['contentId']),
      contentTitle: _string(json['contentTitle']),
      userId: _string(json['userId']),
      userNickname: _string(json['userNickname']),
      userEmail: _string(json['userEmail']),
      createdAt: _date(json['createdAt']),
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

  final String id; // 记录 ID
  final String contentId; // 内容 ID
  final String contentTitle; // 内容标题
  final String userId; // 用户 ID
  final String userNickname; // 用户昵称
  final String userEmail; // 用户邮箱
  final String anonymousId; // 匿名用户 ID
  final String ipHash; // IP 哈希
  final String userAgent; // 浏览器 UA
  final DateTime createdAt; // 创建时间

  /// 是否匿名用户
  bool get anonymous => userId.isEmpty;

  /// 从 JSON 创建实例
  factory AdminViewRecordItem.fromJson(Map<String, dynamic> json) {
    return AdminViewRecordItem(
      id: _string(json['id']),
      contentId: _string(json['contentId']),
      contentTitle: _string(json['contentTitle']),
      userId: _string(json['userId']),
      userNickname: _string(json['userNickname']),
      userEmail: _string(json['userEmail']),
      anonymousId: _string(json['anonymousId']),
      ipHash: _string(json['ipHash']),
      userAgent: _string(json['userAgent']),
      createdAt: _date(json['createdAt']),
    );
  }
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

  final String id; // 活动 ID
  final String type; // 活动类型
  final String contentId; // 内容 ID
  final String title; // 内容标题
  final DateTime createdAt; // 创建时间

  /// 从 JSON 创建实例
  factory UserActivity.fromJson(Map<String, dynamic> json) {
    return UserActivity(
      id: _string(json['id']),
      type: _string(json['type']),
      contentId: _string(json['contentId']),
      title: _string(json['title']),
      createdAt: _date(json['createdAt']),
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

  final String id; // 用户 ID
  final String email; // 邮箱
  final String nickname; // 昵称
  final String avatarUrl; // 头像 URL
  final String bio; // 个人简介
  final String blogUrl; // 博客链接
  final AdminUserRole role; // 用户角色
  final AdminUserStatus status; // 用户状态
  final DateTime createdAt; // 创建时间
  final DateTime updatedAt; // 更新时间

  /// 是否已禁用
  bool get disabled => status == AdminUserStatus.disabled;

  /// 从 JSON 创建实例
  factory AdminUserItem.fromJson(Map<String, dynamic> json) {
    return AdminUserItem(
      id: _string(json['id']),
      email: _string(json['email']),
      nickname: _string(json['nickname']),
      avatarUrl: _string(json['avatarUrl']),
      bio: _string(json['bio']),
      blogUrl: _string(json['blogUrl']),
      role: AdminUserRole.fromApi(_string(json['role'])),
      status: AdminUserStatus.fromApi(_string(json['status'])),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
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

  final String email; // 邮箱
  final String nickname; // 昵称
  final String avatarUrl; // 头像 URL
  final String bio; // 个人简介
  final String blogUrl; // 博客链接
  final AdminUserRole role; // 用户角色
  final AdminUserStatus status; // 用户状态

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

/// AI 配额模型
class AiQuota {
  const AiQuota({required this.dailyLimit, required this.used});

  final int dailyLimit; // 每日限制
  final int used; // 已使用

  /// 剩余配额
  int get remaining => dailyLimit - used;

  /// 从 JSON 创建实例
  factory AiQuota.fromJson(Map<String, dynamic> json) {
    return AiQuota(
      dailyLimit: _int(json['dailyLimit']),
      used: _int(json['used']),
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

  final String sessionId; // 会话 ID
  final String answer; // 回复内容
  final int remainingQuestions; // 剩余问题数
  final int remainingMessages; // 剩余消息数

  /// 从 JSON 创建实例
  factory AiChatReply.fromJson(Map<String, dynamic> json) {
    return AiChatReply(
      sessionId: _string(json['sessionId']),
      answer: _string(json['answer']),
      remainingQuestions: _int(json['remainingQuestions']),
      remainingMessages: _int(json['remainingMessages']),
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

  final String id; // 会话 ID
  final String title; // 会话标题
  final int messageCount; // 消息数量
  final DateTime createdAt; // 创建时间
  final DateTime updatedAt; // 更新时间

  /// 从 JSON 创建实例
  factory AiSessionItem.fromJson(Map<String, dynamic> json) {
    return AiSessionItem(
      id: _string(json['id']),
      title: _string(json['title']),
      messageCount: _int(json['messageCount']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
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

  final String id; // 消息 ID
  final String role; // 角色（user/assistant）
  final String content; // 消息内容
  final DateTime createdAt; // 创建时间

  /// 从 JSON 创建实例
  factory AiMessageItem.fromJson(Map<String, dynamic> json) {
    return AiMessageItem(
      id: _string(json['id']),
      role: _string(json['role']),
      content: _string(json['content']),
      createdAt: _date(json['createdAt']),
    );
  }
}

/// AI 聊天消息角色枚举
enum AiChatMessageRole {
  /// 用户
  user,
  /// 助手
  assistant,
  /// 工具
  tool,
  /// 系统
  system;

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      AiChatMessageRole.user => '用户',
      AiChatMessageRole.assistant => '助手',
      AiChatMessageRole.tool => '工具',
      AiChatMessageRole.system => '系统',
    };
  }

  /// 从 API 字符串值转换为枚举
  static AiChatMessageRole fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'ASSISTANT' => AiChatMessageRole.assistant,
      'TOOL' => AiChatMessageRole.tool,
      'SYSTEM' => AiChatMessageRole.system,
      _ => AiChatMessageRole.user,
    };
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

  final String id; // 会话 ID
  final String userId; // 用户 ID
  final String userNickname; // 用户昵称
  final String userEmail; // 用户邮箱
  final String title; // 会话标题
  final int messageCount; // 消息数量
  final String lastMessage; // 最后一条消息
  final DateTime createdAt; // 创建时间
  final DateTime updatedAt; // 更新时间

  /// 从 JSON 创建实例
  factory AdminAiChatSessionItem.fromJson(Map<String, dynamic> json) {
    return AdminAiChatSessionItem(
      id: _string(json['id']),
      userId: _string(json['userId']),
      userNickname: _string(json['userNickname']),
      userEmail: _string(json['userEmail']),
      title: _string(json['title']),
      messageCount: _int(json['messageCount']),
      lastMessage: _string(json['lastMessage']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
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

  final String id; // 消息 ID
  final AiChatMessageRole role; // 消息角色
  final String content; // 消息内容
  final String toolName; // 工具名称
  final int promptTokens; // 提示词 token 数
  final int completionTokens; // 完成 token 数
  final DateTime createdAt; // 创建时间

  /// 从 JSON 创建实例
  factory AdminAiChatMessageItem.fromJson(Map<String, dynamic> json) {
    return AdminAiChatMessageItem(
      id: _string(json['id']),
      role: AiChatMessageRole.fromApi(_string(json['role'])),
      content: _string(json['content']),
      toolName: _string(json['toolName']),
      promptTokens: _int(json['promptTokens']),
      completionTokens: _int(json['completionTokens']),
      createdAt: _date(json['createdAt']),
    );
  }
}

/// 管理后台 AI 聊天详情模型
class AdminAiChatDetail {
  const AdminAiChatDetail({required this.session, required this.messages});

  final AdminAiChatSessionItem session; // 会话信息
  final List<AdminAiChatMessageItem> messages; // 消息列表

  /// 从 JSON 创建实例
  factory AdminAiChatDetail.fromJson(Map<String, dynamic> json) {
    return AdminAiChatDetail(
      session: AdminAiChatSessionItem.fromJson(
        (json['session'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      messages:
          (json['messages'] as List? ?? const [])
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

/// 管理后台知识库文档项模型
class AdminKnowledgeDocItem {
  const AdminKnowledgeDocItem({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.sourceRef,
    required this.body,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id; // 文档 ID
  final String title; // 标题
  final KnowledgeSourceType sourceType; // 来源类型
  final String sourceRef; // 来源引用
  final String body; // 文档内容
  final bool enabled; // 是否启用
  final DateTime createdAt; // 创建时间
  final DateTime updatedAt; // 更新时间

  /// 从 JSON 创建实例
  factory AdminKnowledgeDocItem.fromJson(Map<String, dynamic> json) {
    return AdminKnowledgeDocItem(
      id: _string(json['id']),
      title: _string(json['title']),
      sourceType: KnowledgeSourceType.fromApi(_string(json['sourceType'])),
      sourceRef: _string(json['sourceRef']),
      body: _string(json['body']),
      enabled: json['enabled'] != false,
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

/// 管理后台知识库文档草稿模型
class AdminKnowledgeDocDraft {
  const AdminKnowledgeDocDraft({
    required this.title,
    required this.sourceType,
    required this.sourceRef,
    required this.body,
    required this.enabled,
  });

  final String title; // 标题
  final KnowledgeSourceType sourceType; // 来源类型
  final String sourceRef; // 来源引用
  final String body; // 文档内容
  final bool enabled; // 是否启用

  /// 从 AdminKnowledgeDocItem 创建草稿
  factory AdminKnowledgeDocDraft.fromItem(AdminKnowledgeDocItem item) {
    return AdminKnowledgeDocDraft(
      title: item.title,
      sourceType: item.sourceType,
      sourceRef: item.sourceRef,
      body: item.body,
      enabled: item.enabled,
    );
  }

  /// 转换为 JSON Map
  Map<String, Object?> toJson() {
    return {
      'title': title.trim(),
      'sourceType': sourceType.apiValue,
      'sourceRef': sourceRef.trim(),
      'body': body.trim(),
      'enabled': enabled,
    };
  }
}

/// 认证会话模型
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken; // 访问令牌
  final String refreshToken; // 刷新令牌
  final DateTime expiresAt; // 过期时间
  final UserProfile user; // 用户信息

  /// 从 JSON 创建实例
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: _string(json['accessToken']),
      refreshToken: _string(json['refreshToken']),
      expiresAt: _date(json['expiresAt']),
      user: UserProfile.fromJson((json['user'] as Map).cast<String, dynamic>()),
    );
  }
}

/// OAuth 账户绑定信息模型
class OAuthAccountInfo {
  const OAuthAccountInfo({
    required this.provider,
    required this.providerUsername,
    required this.createdAt,
  });

  final String provider; // OAuth 提供者名称（如 GITHUB）
  final String providerUsername; // 第三方平台用户名
  final DateTime createdAt; // 绑定时间

  factory OAuthAccountInfo.fromJson(Map<String, dynamic> json) {
    return OAuthAccountInfo(
      provider: _string(json['provider']),
      providerUsername: _string(json['providerUsername']),
      createdAt: _date(json['createdAt']),
    );
  }
}

/// 友情链接模型
class FriendLink {
  const FriendLink({
    required this.id,
    required this.name,
    required this.intro,
    required this.avatarUrl,
    required this.siteUrl,
    this.visible = true,
    this.sortOrder = 0,
  });

  final String id; // 链接 ID
  final String name; // 网站名称
  final String intro; // 简介
  final String avatarUrl; // 头像 URL
  final String siteUrl; // 网站链接
  final bool visible; // 是否可见
  final int sortOrder; // 排序顺序

  /// 从 JSON 创建实例
  factory FriendLink.fromJson(Map<String, dynamic> json) {
    return FriendLink(
      id: _string(json['id']),
      name: _string(json['name']),
      intro: _string(json['intro']),
      avatarUrl: _string(json['avatarUrl']),
      siteUrl: _string(json['siteUrl']),
      visible: json['visible'] != false,
      sortOrder: _int(json['sortOrder']),
    );
  }
}

/// 友情链接草稿模型
class FriendDraft {
  const FriendDraft({
    required this.name,
    required this.intro,
    required this.avatarUrl,
    required this.siteUrl,
    required this.visible,
    required this.sortOrder,
  });

  final String name; // 网站名称
  final String intro; // 简介
  final String avatarUrl; // 头像 URL
  final String siteUrl; // 网站链接
  final bool visible; // 是否可见
  final int sortOrder; // 排序顺序

  /// 从 FriendLink 创建草稿
  factory FriendDraft.fromItem(FriendLink item) {
    return FriendDraft(
      name: item.name,
      intro: item.intro,
      avatarUrl: item.avatarUrl,
      siteUrl: item.siteUrl,
      visible: item.visible,
      sortOrder: item.sortOrder,
    );
  }

  /// 转换为 JSON Map
  Map<String, Object?> toJson() {
    return {
      'name': name.trim(),
      'intro': intro.trim(),
      'avatarUrl': avatarUrl.trim(),
      'siteUrl': siteUrl.trim(),
      'visible': visible,
      'sortOrder': sortOrder,
    };
  }
}

/// 管理后台指标模型
class AdminMetric {
  const AdminMetric(this.label, this.value);

  final String label; // 指标标签
  final String value; // 指标值
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

  final int contents; // 内容数量
  final int media; // 媒体数量
  final int friends; // 友链数量
  final int users; // 用户数量
  final int comments; // 评论数量
  final int likes; // 点赞数量
  final int views; // 浏览数量
  final int aiChats; // AI 会话数量
  final int knowledgeDocs; // 知识库文档数量

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
      contents: _int(json['contents']),
      media: _int(json['media']),
      friends: _int(json['friends']),
      users: _int(json['users']),
      comments: _int(json['comments']),
      likes: _int(json['likes']),
      views: _int(json['views']),
      aiChats: _int(json['aiChats']),
      knowledgeDocs: _int(json['knowledgeDocs']),
    );
  }
}

/// 标签项模型
class TagItem {
  const TagItem({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
  });

  final String id; // 标签 ID
  final String name; // 标签名称
  final String slug; // URL 别名
  final String description; // 描述

  /// 从 JSON 创建实例
  factory TagItem.fromJson(Map<String, dynamic> json) {
    return TagItem(
      id: _string(json['id']),
      name: _string(json['name']),
      slug: _string(json['slug']),
      description: _string(json['description']),
    );
  }
}

/// 标签草稿模型
class TagDraft {
  const TagDraft({
    required this.name,
    required this.slug,
    required this.description,
  });

  final String name; // 标签名称
  final String slug; // URL 别名
  final String description; // 描述

  /// 转换为 JSON Map
  Map<String, Object?> toJson() {
    return {
      'name': name.trim(),
      'slug': slug.trim(),
      'description': description.trim(),
    };
  }
}

/// 管理后台内容项模型
class AdminContentItem {
  const AdminContentItem({
    required this.id,
    required this.title,
    required this.slug,
    required this.type,
    required this.status,
    required this.summary,
    required this.bodyMarkdown,
    required this.pinned,
    required this.coverMediaId,
    required this.coverUrl,
    required this.mediaCount,
    required this.mediaUrls,
    required this.likeCount,
    required this.viewCount,
    required this.commentCount,
    required this.publishedAt,
    required this.tags,
  });

  final String id; // 内容 ID
  final String title; // 标题
  final String slug; // URL 别名
  final ContentType type; // 内容类型
  final ContentStatus status; // 内容状态
  final String summary; // 摘要
  final String bodyMarkdown; // Markdown 内容
  final bool pinned; // 是否置顶
  final String coverMediaId; // 封面媒体 ID
  final String coverUrl; // 封面 URL
  final int mediaCount; // 媒体数量
  final List<String> mediaUrls; // 媒体 URL 列表
  final int likeCount; // 点赞数
  final int viewCount; // 浏览数
  final int commentCount; // 评论数
  final DateTime publishedAt; // 发布时间
  final List<TagItem> tags; // 标签列表

  /// 是否已归档
  bool get archived => status == ContentStatus.archived;

  /// 从 JSON 创建实例
  factory AdminContentItem.fromJson(Map<String, dynamic> json) {
    return AdminContentItem(
      id: _string(json['id']),
      title: _string(json['title']),
      slug: _string(json['slug']),
      type: ContentType.fromApi(_string(json['type'])),
      status: ContentStatus.fromApi(_string(json['status'])),
      summary: _string(json['summary']),
      bodyMarkdown: _string(json['bodyMarkdown']),
      pinned: json['pinned'] == true,
      coverMediaId: _string(json['coverMediaId']),
      coverUrl: _string(json['coverUrl']),
      mediaCount: _int(json['mediaCount']),
      mediaUrls: _stringList(json['mediaUrls']),
      likeCount: _int(json['likeCount']),
      viewCount: _int(json['viewCount']),
      commentCount: _int(json['commentCount']),
      publishedAt: _date(json['publishedAt']),
      tags: _tagItems(json['tags']),
    );
  }
}

/// 管理后台媒体项模型
class AdminMediaItem {
  const AdminMediaItem({
    required this.id,
    required this.contentId,
    required this.contentTitle,
    required this.type,
    required this.publicUrl,
    required this.filename,
    required this.contentType,
    required this.byteSize,
    required this.width,
    required this.height,
    required this.durationSeconds,
    required this.cover,
    required this.createdAt,
  });

  final String id; // 媒体 ID
  final String contentId; // 内容 ID
  final String contentTitle; // 内容标题
  final MediaAssetType type; // 媒体类型
  final String publicUrl; // 公开 URL
  final String filename; // 文件名
  final String contentType; // 内容类型
  final int byteSize; // 文件大小（字节）
  final int width; // 宽度
  final int height; // 高度
  final int durationSeconds; // 时长（秒）
  final bool cover; // 是否封面
  final DateTime createdAt; // 创建时间

  /// 获取显示名称
  String get displayName {
    if (filename.isNotEmpty) return filename;
    if (publicUrl.isNotEmpty) return publicUrl;
    return id;
  }

  /// 从 JSON 创建实例
  factory AdminMediaItem.fromJson(Map<String, dynamic> json) {
    return AdminMediaItem(
      id: _string(json['id']),
      contentId: _string(json['contentId']),
      contentTitle: _string(json['contentTitle']),
      type: MediaAssetType.fromApi(_string(json['type'])),
      publicUrl: _string(json['publicUrl']),
      filename: _string(json['filename']),
      contentType: _string(json['contentType']),
      byteSize: _int(json['byteSize']),
      width: _int(json['width']),
      height: _int(json['height']),
      durationSeconds: _int(json['durationSeconds']),
      cover: json['cover'] == true,
      createdAt: _date(json['createdAt']),
    );
  }
}

/// 管理后台媒体草稿模型
class AdminMediaDraft {
  const AdminMediaDraft({
    required this.contentId,
    required this.type,
    required this.publicUrl,
    required this.filename,
    required this.contentType,
    required this.byteSize,
    required this.width,
    required this.height,
    required this.durationSeconds,
  });

  final String contentId; // 内容 ID
  final MediaAssetType type; // 媒体类型
  final String publicUrl; // 公开 URL
  final String filename; // 文件名
  final String contentType; // 内容类型
  final int? byteSize; // 文件大小（字节）
  final int? width; // 宽度
  final int? height; // 高度
  final int? durationSeconds; // 时长（秒）

  /// 从 AdminMediaItem 创建草稿
  factory AdminMediaDraft.fromItem(AdminMediaItem item) {
    return AdminMediaDraft(
      contentId: item.contentId,
      type: item.type,
      publicUrl: item.publicUrl,
      filename: item.filename,
      contentType: item.contentType,
      byteSize: item.byteSize == 0 ? null : item.byteSize,
      width: item.width == 0 ? null : item.width,
      height: item.height == 0 ? null : item.height,
      durationSeconds: item.durationSeconds == 0 ? null : item.durationSeconds,
    );
  }

  /// 转换为 JSON Map
  Map<String, Object?> toJson() {
    return {
      'contentId': contentId.isEmpty ? null : contentId,
      'type': type.apiValue,
      'publicUrl': publicUrl.trim(),
      'filename': filename.trim(),
      'contentType': contentType.trim(),
      'byteSize': byteSize,
      'width': width,
      'height': height,
      'durationSeconds': durationSeconds,
    };
  }
}

/// 管理后台内容草稿模型
class AdminContentDraft {
  const AdminContentDraft({
    required this.title,
    required this.slug,
    required this.type,
    required this.status,
    required this.summary,
    required this.bodyMarkdown,
    required this.pinned,
    required this.tagSlugs,
    this.mediaUrls = const [],
  });

  final String title; // 标题
  final String slug; // URL 别名
  final ContentType type; // 内容类型
  final ContentStatus status; // 内容状态
  final String summary; // 摘要
  final String bodyMarkdown; // Markdown 内容
  final bool pinned; // 是否置顶
  final List<String> tagSlugs; // 标签 slug 列表
  final List<String> mediaUrls; // 媒体 URL 列表

  /// 从 AdminContentItem 创建草稿
  factory AdminContentDraft.fromItem(AdminContentItem item) {
    return AdminContentDraft(
      title: item.title,
      slug: item.slug,
      type: item.type,
      status: item.status,
      summary: item.summary,
      bodyMarkdown: item.bodyMarkdown,
      pinned: item.pinned,
      tagSlugs: item.tags.map((tag) => tag.slug).toList(),
      mediaUrls: item.mediaUrls,
    );
  }

  /// 转换为 JSON Map
  Map<String, Object?> toJson() {
    return {
      'title': title.trim(),
      'slug': slug.trim(),
      'type': type.apiValue,
      'status': status.apiValue,
      'summary': summary.trim(),
      'bodyMarkdown': bodyMarkdown.trim(),
      'pinned': pinned,
      'tagSlugs': tagSlugs,
      'mediaUrls': mediaUrls,
    };
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

  final String id; // 日志 ID
  final String? actorUserId; // 操作者用户 ID
  final String? actorNickname; // 操作者昵称
  final String action; // 操作类型
  final String resourceType; // 资源类型
  final String? resourceId; // 资源 ID
  final String? detail; // 详情
  final DateTime createdAt; // 创建时间

  /// 从 JSON 创建实例
  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: _string(json['id']),
      actorUserId: _nullableString(json['actorUserId']),
      actorNickname: _nullableString(json['actorNickname']),
      action: _string(json['action']),
      resourceType: _string(json['resourceType']),
      resourceId: _nullableString(json['resourceId']),
      detail: _nullableString(json['detail']),
      createdAt: _date(json['createdAt']),
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

  final String? action; // 操作类型筛选
  final String? resourceType; // 资源类型筛选
  final int page; // 页码
  final int size; // 每页大小

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

/// 从 JSON 列表解析 BlogContent 列表
List<BlogContent> _contentList(Object? value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => BlogContent.fromSummaryJson(item.cast<String, dynamic>()))
      .toList();
}

/// 从 JSON 列表解析 TagItem 列表
List<TagItem> _tagItems(Object? value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => TagItem.fromJson(item.cast<String, dynamic>()))
      .toList();
}

/// 从媒体资源列表提取公开 URL 列表
List<String> _mediaUrls(Object? value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => _string(item['publicUrl']))
      .where((url) => url.isNotEmpty)
      .toList();
}

/// 从 JSON 列表解析字符串列表
List<String> _stringList(Object? value) {
  return (value as List? ?? const [])
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
}

/// 安全转换为字符串，null 转为空字符串
String _string(Object? value) => value?.toString() ?? '';

/// 转换为可空字符串，空字符串转为 null
String? _nullableString(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

/// 安全转换为 int，转换失败返回 0
int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

/// 安全转换为 DateTime，转换失败返回 epoch 时间
DateTime _date(Object? value) =>
    DateTime.tryParse(_string(value))?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(0);
