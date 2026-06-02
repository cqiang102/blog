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
    this.page = 0,
    this.size = 10,
  });

  final String query;
  final String? tag;
  final ContentType? type;
  final int page;
  final int size;

  @override
  bool operator ==(Object other) {
    return other is ContentListQuery &&
        other.query == query &&
        other.tag == tag &&
        other.type == type &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(query, tag, type, page, size);
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
    required this.authorNickname,
    required this.createdAt,
  });

  final String id;
  final String contentId;
  final String contentTitle;
  final String body;
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
      authorNickname: nickname.isEmpty ? '用户' : nickname,
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
  });

  final String sessionId;
  final String answer;
  final int remainingQuestions;

  factory AiChatReply.fromJson(Map<String, dynamic> json) {
    return AiChatReply(
      sessionId: _string(json['sessionId']),
      answer: _string(json['answer']),
      remainingQuestions: _int(json['remainingQuestions']),
    );
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
    required this.name,
    required this.intro,
    required this.avatarUrl,
    required this.siteUrl,
  });

  final String name;
  final String intro;
  final String avatarUrl;
  final String siteUrl;
}

class AdminMetric {
  const AdminMetric(this.label, this.value);

  final String label;
  final String value;
}

List<BlogContent> _contentList(Object? value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => BlogContent.fromSummaryJson(item.cast<String, dynamic>()))
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
