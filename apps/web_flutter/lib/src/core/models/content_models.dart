// 内容相关数据模型
// 包含博客内容、推荐内容、内容查询参数等

import 'package:json_annotation/json_annotation.dart';

import 'common_models.dart';
import 'enums.dart';
import 'helpers.dart';
import 'json_converters.dart';

part 'content_models.g.dart';

/// 博客内容模型
/// 包含文章的基本信息、统计数据和媒体资源
/// 保留手写工厂：fromSummaryJson 和 fromDetailJson 解析不同 API 响应
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
    this.status = ContentStatus.published,
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
  final ContentStatus status;
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

  /// 从列表摘要 JSON 创建实例
  factory BlogContent.fromSummaryJson(Map<String, dynamic> json) {
    return BlogContent(
      id: jsonString(json['id']),
      title: jsonString(json['title']),
      slug: jsonString(json['slug']),
      type: ContentType.fromApi(jsonString(json['type'])),
      status: ContentStatus.fromApi(jsonString(json['status'])),
      summary: jsonString(json['summary']),
      coverUrl: jsonString(json['coverUrl']),
      tags: jsonStringList(json['tags']),
      pinned: json['pinned'] == true,
      likeCount: jsonInt(json['likeCount']),
      publishedAt: jsonDate(json['publishedAt']),
    );
  }

  /// 从详情 JSON 创建实例（包含完整内容和媒体）
  factory BlogContent.fromDetailJson(Map<String, dynamic> json) {
    final mediaUrls = _mediaUrls(json['mediaAssets']);
    final rawCoverUrl = jsonString(json['coverUrl']);
    return BlogContent(
      id: jsonString(json['id']),
      title: jsonString(json['title']),
      slug: jsonString(json['slug']),
      type: ContentType.fromApi(jsonString(json['type'])),
      summary: jsonString(json['summary']),
      coverUrl: rawCoverUrl.isNotEmpty
          ? rawCoverUrl
          : (mediaUrls.isEmpty ? '' : mediaUrls.first),
      tags: jsonStringList(json['tags']),
      pinned: json['pinned'] == true,
      likeCount: jsonInt(json['likeCount']),
      viewCount: jsonInt(json['viewCount']),
      commentCount: jsonInt(json['commentCount']),
      likedByCurrentUser: json['likedByCurrentUser'] == true,
      publishedAt: jsonDate(json['publishedAt']),
      markdown: jsonString(json['bodyMarkdown']),
      mediaUrls: mediaUrls,
    );
  }
}

/// 从媒体资源列表提取公开 URL 列表
List<String> _mediaUrls(Object? value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => jsonString(item['publicUrl']))
      .where((url) => url.isNotEmpty)
      .toList();
}

/// 首页推荐内容模型
/// 包含置顶、最新和最热文章列表
/// 保留手写 fromJson：使用 BlogContent.fromSummaryJson
class Recommendations {
  const Recommendations({
    required this.pinned,
    required this.latest,
    required this.mostLiked,
  });

  final List<BlogContent> pinned;
  final List<BlogContent> latest;
  final List<BlogContent> mostLiked;

  /// 从 JSON 创建实例
  factory Recommendations.fromJson(Map<String, dynamic> json) {
    return Recommendations(
      pinned: _contentList(json['pinned']),
      latest: _contentList(json['latest']),
      mostLiked: _contentList(json['mostLiked']),
    );
  }
}

/// 从 JSON 列表解析 BlogContent 列表
List<BlogContent> _contentList(Object? value) {
  return (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => BlogContent.fromSummaryJson(item.cast<String, dynamic>()))
      .toList();
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
  int get hashCode =>
      Object.hash(query, tag, type, startDate, endDate, page, size);
}

/// 管理后台内容列表查询参数
class AdminContentQuery {
  const AdminContentQuery({
    this.query = '',
    this.status,
    this.type,
    this.includeDeleted = false,
    this.page = 0,
    this.size = 20,
  });

  final String query;
  final ContentStatus? status;
  final ContentType? type;
  final bool includeDeleted;
  final int page;
  final int size;

  AdminContentQuery copyWith({
    String? query,
    ContentStatus? status,
    bool clearStatus = false,
    ContentType? type,
    bool clearType = false,
    bool? includeDeleted,
    int? page,
    int? size,
  }) {
    return AdminContentQuery(
      query: query ?? this.query,
      status: clearStatus ? null : (status ?? this.status),
      type: clearType ? null : (type ?? this.type),
      includeDeleted: includeDeleted ?? this.includeDeleted,
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AdminContentQuery &&
        other.query == query &&
        other.status == status &&
        other.type == type &&
        other.includeDeleted == includeDeleted &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode =>
      Object.hash(query, status, type, includeDeleted, page, size);
}

/// 管理后台内容项模型
@JsonSerializable()
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
    this.deletedAt,
  });

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String title;
  @SafeStringJsonConverter()
  final String slug;
  @ContentTypeJsonConverter()
  final ContentType type;
  @ContentStatusJsonConverter()
  final ContentStatus status;
  @SafeStringJsonConverter()
  final String summary;
  @SafeStringJsonConverter()
  final String bodyMarkdown;
  @JsonKey(defaultValue: false)
  final bool pinned;
  @SafeStringJsonConverter()
  final String coverMediaId;
  @SafeStringJsonConverter()
  final String coverUrl;
  @SafeIntJsonConverter()
  final int mediaCount;
  @SafeStringListJsonConverter()
  final List<String> mediaUrls;
  @SafeIntJsonConverter()
  final int likeCount;
  @SafeIntJsonConverter()
  final int viewCount;
  @SafeIntJsonConverter()
  final int commentCount;
  @SafeDateTimeJsonConverter()
  final DateTime publishedAt;
  @NullableSafeDateTimeJsonConverter()
  final DateTime? deletedAt;
  final List<TagItem> tags;

  /// 是否已归档
  bool get archived => status == ContentStatus.archived;

  /// 是否已被逻辑删除
  bool get deleted => deletedAt != null;

  factory AdminContentItem.fromJson(Map<String, dynamic> json) =>
      _$AdminContentItemFromJson(json);

  Map<String, dynamic> toJson() => _$AdminContentItemToJson(this);
}

/// 管理后台内容草稿模型
/// 保留手写 toJson：包含 .trim() 调用和条件字段
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
    this.coverUrl,
    this.publishedAt,
  });

  final String title;
  final String slug;
  final ContentType type;
  final ContentStatus status;
  final String summary;
  final String bodyMarkdown;
  final bool pinned;
  final List<String> tagSlugs;
  final List<String> mediaUrls;
  final String? coverUrl;
  final DateTime? publishedAt;

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
      coverUrl: item.coverUrl,
      publishedAt: item.publishedAt,
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
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (publishedAt != null)
        'publishedAt': publishedAt!.toUtc().toIso8601String(),
    };
  }
}
