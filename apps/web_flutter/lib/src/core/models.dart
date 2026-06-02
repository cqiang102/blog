enum ContentType {
  text,
  article,
  image,
  video;

  String get apiValue {
    return switch (this) {
      ContentType.text => 'TEXT',
      ContentType.article => 'ARTICLE',
      ContentType.image => 'IMAGE',
      ContentType.video => 'VIDEO',
    };
  }

  String get label {
    return switch (this) {
      ContentType.text => '文本',
      ContentType.article => '图文',
      ContentType.image => '图片',
      ContentType.video => '视频',
    };
  }

  static ContentType fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'TEXT' => ContentType.text,
      'IMAGE' => ContentType.image,
      'VIDEO' => ContentType.video,
      _ => ContentType.article,
    };
  }
}

enum ContentStatus {
  draft,
  published,
  archived;

  String get apiValue {
    return switch (this) {
      ContentStatus.draft => 'DRAFT',
      ContentStatus.published => 'PUBLISHED',
      ContentStatus.archived => 'ARCHIVED',
    };
  }

  String get label {
    return switch (this) {
      ContentStatus.draft => '草稿',
      ContentStatus.published => '已发布',
      ContentStatus.archived => '已归档',
    };
  }

  static ContentStatus fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'PUBLISHED' => ContentStatus.published,
      'ARCHIVED' => ContentStatus.archived,
      _ => ContentStatus.draft,
    };
  }
}

enum MediaAssetType {
  image,
  video,
  file;

  String get apiValue {
    return switch (this) {
      MediaAssetType.image => 'IMAGE',
      MediaAssetType.video => 'VIDEO',
      MediaAssetType.file => 'FILE',
    };
  }

  String get label {
    return switch (this) {
      MediaAssetType.image => '图片',
      MediaAssetType.video => '视频',
      MediaAssetType.file => '文件',
    };
  }

  static MediaAssetType fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'VIDEO' => MediaAssetType.video,
      'FILE' => MediaAssetType.file,
      _ => MediaAssetType.image,
    };
  }
}

enum AdminCommentStatus {
  visible,
  deleted;

  String get apiValue {
    return switch (this) {
      AdminCommentStatus.visible => 'VISIBLE',
      AdminCommentStatus.deleted => 'DELETED',
    };
  }

  String get label {
    return switch (this) {
      AdminCommentStatus.visible => '可见',
      AdminCommentStatus.deleted => '已删除',
    };
  }

  static AdminCommentStatus fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'DELETED' => AdminCommentStatus.deleted,
      _ => AdminCommentStatus.visible,
    };
  }
}

enum AdminUserRole {
  user,
  admin;

  String get apiValue {
    return switch (this) {
      AdminUserRole.user => 'USER',
      AdminUserRole.admin => 'ADMIN',
    };
  }

  String get label {
    return switch (this) {
      AdminUserRole.user => '普通用户',
      AdminUserRole.admin => '管理员',
    };
  }

  static AdminUserRole fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'ADMIN' => AdminUserRole.admin,
      _ => AdminUserRole.user,
    };
  }
}

enum AdminUserStatus {
  active,
  disabled;

  String get apiValue {
    return switch (this) {
      AdminUserStatus.active => 'ACTIVE',
      AdminUserStatus.disabled => 'DISABLED',
    };
  }

  String get label {
    return switch (this) {
      AdminUserStatus.active => '启用',
      AdminUserStatus.disabled => '禁用',
    };
  }

  static AdminUserStatus fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'DISABLED' => AdminUserStatus.disabled,
      _ => AdminUserStatus.active,
    };
  }
}

enum KnowledgeSourceType {
  manual,
  url,
  file,
  content;

  String get apiValue {
    return switch (this) {
      KnowledgeSourceType.manual => 'MANUAL',
      KnowledgeSourceType.url => 'URL',
      KnowledgeSourceType.file => 'FILE',
      KnowledgeSourceType.content => 'CONTENT',
    };
  }

  String get label {
    return switch (this) {
      KnowledgeSourceType.manual => '手动录入',
      KnowledgeSourceType.url => '网页',
      KnowledgeSourceType.file => '文件',
      KnowledgeSourceType.content => '内容引用',
    };
  }

  static KnowledgeSourceType fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'URL' => KnowledgeSourceType.url,
      'FILE' => KnowledgeSourceType.file,
      'CONTENT' => KnowledgeSourceType.content,
      _ => KnowledgeSourceType.manual,
    };
  }
}

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

  final String id;
  final String title;
  final String slug;
  final ContentType type;
  final String summary;
  final String coverUrl;
  final List<String> tags;
  final bool pinned;
  final int likeCount;
  final int viewCount;
  final int commentCount;
  final bool likedByCurrentUser;
  final DateTime publishedAt;
  final String markdown;
  final List<String> mediaUrls;

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

class Recommendations {
  const Recommendations({
    required this.pinned,
    required this.latest,
    required this.mostLiked,
  });

  final List<BlogContent> pinned;
  final List<BlogContent> latest;
  final List<BlogContent> mostLiked;

  factory Recommendations.fromJson(Map<String, dynamic> json) {
    return Recommendations(
      pinned: _contentList(json['pinned']),
      latest: _contentList(json['latest']),
      mostLiked: _contentList(json['mostLiked']),
    );
  }
}

class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  final List<T> items;
  final int page;
  final int size;
  final int total;
}

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

  final String query;
  final String? tag;
  final ContentType? type;
  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final int size;

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

class AdminKnowledgeDocQuery {
  const AdminKnowledgeDocQuery({
    this.query = '',
    this.enabled,
    this.page = 0,
    this.size = 50,
  });

  final String query;
  final bool? enabled;
  final int page;
  final int size;

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

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    required this.role,
    this.avatarUrl,
    this.bio,
    this.blogUrl,
  });

  final String id;
  final String email;
  final String nickname;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final String? blogUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: _string(json['id']),
      email: _string(json['email']),
      nickname: _string(json['nickname']),
      role: _string(json['role']).isEmpty ? 'USER' : _string(json['role']),
      avatarUrl: _nullableString(json['avatarUrl']),
      bio: _nullableString(json['bio']),
      blogUrl: _nullableString(json['blogUrl']),
    );
  }

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

class CommentItem {
  const CommentItem({
    required this.id,
    required this.contentId,
    required this.contentTitle,
    required this.body,
    required this.authorId,
    required this.authorNickname,
    required this.createdAt,
  });

  final String id;
  final String contentId;
  final String contentTitle;
  final String body;
  final String authorId;
  final String authorNickname;
  final DateTime createdAt;

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
    );
  }
}

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

  bool get deleted => status == AdminCommentStatus.deleted;

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

  bool get anonymous => userId.isEmpty;

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

  bool get disabled => status == AdminUserStatus.disabled;

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

class AiQuota {
  const AiQuota({required this.dailyLimit, required this.used});

  final int dailyLimit;
  final int used;

  int get remaining => dailyLimit - used;

  factory AiQuota.fromJson(Map<String, dynamic> json) {
    return AiQuota(
      dailyLimit: _int(json['dailyLimit']),
      used: _int(json['used']),
    );
  }
}

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

  factory AiChatReply.fromJson(Map<String, dynamic> json) {
    return AiChatReply(
      sessionId: _string(json['sessionId']),
      answer: _string(json['answer']),
      remainingQuestions: _int(json['remainingQuestions']),
      remainingMessages: _int(json['remainingMessages']),
    );
  }
}

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

  factory AiMessageItem.fromJson(Map<String, dynamic> json) {
    return AiMessageItem(
      id: _string(json['id']),
      role: _string(json['role']),
      content: _string(json['content']),
      createdAt: _date(json['createdAt']),
    );
  }
}

enum AiChatMessageRole {
  user,
  assistant,
  tool,
  system;

  String get label {
    return switch (this) {
      AiChatMessageRole.user => '用户',
      AiChatMessageRole.assistant => '助手',
      AiChatMessageRole.tool => '工具',
      AiChatMessageRole.system => '系统',
    };
  }

  static AiChatMessageRole fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'ASSISTANT' => AiChatMessageRole.assistant,
      'TOOL' => AiChatMessageRole.tool,
      'SYSTEM' => AiChatMessageRole.system,
      _ => AiChatMessageRole.user,
    };
  }
}

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

class AdminAiChatDetail {
  const AdminAiChatDetail({required this.session, required this.messages});

  final AdminAiChatSessionItem session;
  final List<AdminAiChatMessageItem> messages;

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

  final String id;
  final String title;
  final KnowledgeSourceType sourceType;
  final String sourceRef;
  final String body;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

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

class AdminKnowledgeDocDraft {
  const AdminKnowledgeDocDraft({
    required this.title,
    required this.sourceType,
    required this.sourceRef,
    required this.body,
    required this.enabled,
  });

  final String title;
  final KnowledgeSourceType sourceType;
  final String sourceRef;
  final String body;
  final bool enabled;

  factory AdminKnowledgeDocDraft.fromItem(AdminKnowledgeDocItem item) {
    return AdminKnowledgeDocDraft(
      title: item.title,
      sourceType: item.sourceType,
      sourceRef: item.sourceRef,
      body: item.body,
      enabled: item.enabled,
    );
  }

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

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final UserProfile user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: _string(json['accessToken']),
      refreshToken: _string(json['refreshToken']),
      expiresAt: _date(json['expiresAt']),
      user: UserProfile.fromJson((json['user'] as Map).cast<String, dynamic>()),
    );
  }
}

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

  final String id;
  final String name;
  final String intro;
  final String avatarUrl;
  final String siteUrl;
  final bool visible;
  final int sortOrder;

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

class FriendDraft {
  const FriendDraft({
    required this.name,
    required this.intro,
    required this.avatarUrl,
    required this.siteUrl,
    required this.visible,
    required this.sortOrder,
  });

  final String name;
  final String intro;
  final String avatarUrl;
  final String siteUrl;
  final bool visible;
  final int sortOrder;

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

class AdminMetric {
  const AdminMetric(this.label, this.value);

  final String label;
  final String value;
}

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

class TagItem {
  const TagItem({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
  });

  final String id;
  final String name;
  final String slug;
  final String description;

  factory TagItem.fromJson(Map<String, dynamic> json) {
    return TagItem(
      id: _string(json['id']),
      name: _string(json['name']),
      slug: _string(json['slug']),
      description: _string(json['description']),
    );
  }
}

class TagDraft {
  const TagDraft({
    required this.name,
    required this.slug,
    required this.description,
  });

  final String name;
  final String slug;
  final String description;

  Map<String, Object?> toJson() {
    return {
      'name': name.trim(),
      'slug': slug.trim(),
      'description': description.trim(),
    };
  }
}

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
    required this.likeCount,
    required this.viewCount,
    required this.commentCount,
    required this.publishedAt,
    required this.tags,
  });

  final String id;
  final String title;
  final String slug;
  final ContentType type;
  final ContentStatus status;
  final String summary;
  final String bodyMarkdown;
  final bool pinned;
  final String coverMediaId;
  final String coverUrl;
  final int mediaCount;
  final int likeCount;
  final int viewCount;
  final int commentCount;
  final DateTime publishedAt;
  final List<TagItem> tags;

  bool get archived => status == ContentStatus.archived;

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
      likeCount: _int(json['likeCount']),
      viewCount: _int(json['viewCount']),
      commentCount: _int(json['commentCount']),
      publishedAt: _date(json['publishedAt']),
      tags: _tagItems(json['tags']),
    );
  }
}

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

  final String id;
  final String contentId;
  final String contentTitle;
  final MediaAssetType type;
  final String publicUrl;
  final String filename;
  final String contentType;
  final int byteSize;
  final int width;
  final int height;
  final int durationSeconds;
  final bool cover;
  final DateTime createdAt;

  String get displayName {
    if (filename.isNotEmpty) return filename;
    if (publicUrl.isNotEmpty) return publicUrl;
    return id;
  }

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

  final String contentId;
  final MediaAssetType type;
  final String publicUrl;
  final String filename;
  final String contentType;
  final int? byteSize;
  final int? width;
  final int? height;
  final int? durationSeconds;

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
  });

  final String title;
  final String slug;
  final ContentType type;
  final ContentStatus status;
  final String summary;
  final String bodyMarkdown;
  final bool pinned;
  final List<String> tagSlugs;

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
    );
  }

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
    };
  }
}

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

List<BlogContent> _contentList(Object? value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => BlogContent.fromSummaryJson(item.cast<String, dynamic>()))
      .toList();
}

List<TagItem> _tagItems(Object? value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => TagItem.fromJson(item.cast<String, dynamic>()))
      .toList();
}

List<String> _mediaUrls(Object? value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => _string(item['publicUrl']))
      .where((url) => url.isNotEmpty)
      .toList();
}

List<String> _stringList(Object? value) {
  return (value as List? ?? const [])
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _string(Object? value) => value?.toString() ?? '';

String? _nullableString(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

DateTime _date(Object? value) =>
    DateTime.tryParse(_string(value))?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(0);
