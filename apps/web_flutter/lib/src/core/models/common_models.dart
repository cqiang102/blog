// 通用数据模型
// 包含分页结果、标签、友情链接、媒体等

import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';
import 'json_converters.dart';

part 'common_models.g.dart';

/// 分页结果泛型模型
/// [T] 数据项类型
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

/// Generic page-only query used by admin resources without filters.
class AdminPageQuery {
  const AdminPageQuery({this.page = 0, this.size = 50});

  final int page;
  final int size;

  AdminPageQuery copyWith({int? page, int? size}) {
    return AdminPageQuery(page: page ?? this.page, size: size ?? this.size);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminPageQuery && other.page == page && other.size == size;
  }

  @override
  int get hashCode => Object.hash(page, size);
}

/// 标签项模型
@JsonSerializable()
class TagItem {
  const TagItem({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.createdAt,
    this.updatedAt,
  });

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String name;
  @SafeStringJsonConverter()
  final String slug;
  @JsonKey(defaultValue: '')
  final String description;
  @NullableSafeDateTimeJsonConverter()
  final DateTime? createdAt;
  @NullableSafeDateTimeJsonConverter()
  final DateTime? updatedAt;

  factory TagItem.fromJson(Map<String, dynamic> json) =>
      _$TagItemFromJson(json);

  Map<String, dynamic> toJson() => _$TagItemToJson(this);
}

/// 标签草稿模型
/// 保留手写 toJson：包含 .trim() 调用
class TagDraft {
  const TagDraft({
    required this.name,
    required this.slug,
    required this.description,
  });

  final String name;
  final String slug;
  final String description;

  /// 转换为 JSON Map
  Map<String, Object?> toJson() {
    return {
      'name': name.trim(),
      'slug': slug.trim(),
      'description': description.trim(),
    };
  }
}

/// 友情链接模型
@JsonSerializable()
class FriendLink {
  const FriendLink({
    required this.id,
    required this.name,
    required this.intro,
    required this.avatarUrl,
    required this.siteUrl,
    this.visible = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String name;
  @SafeStringJsonConverter()
  final String intro;
  @SafeStringJsonConverter()
  final String avatarUrl;
  @SafeStringJsonConverter()
  final String siteUrl;
  @JsonKey(defaultValue: true)
  final bool visible;
  @JsonKey(defaultValue: 0)
  final int sortOrder;
  @NullableSafeDateTimeJsonConverter()
  final DateTime? createdAt;
  @NullableSafeDateTimeJsonConverter()
  final DateTime? updatedAt;

  factory FriendLink.fromJson(Map<String, dynamic> json) =>
      _$FriendLinkFromJson(json);

  Map<String, dynamic> toJson() => _$FriendLinkToJson(this);
}

/// 友情链接草稿模型
/// 保留手写 toJson：包含 .trim() 调用
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

/// 管理后台媒体项模型
@JsonSerializable()
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

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String contentId;
  @SafeStringJsonConverter()
  final String contentTitle;
  @MediaAssetTypeJsonConverter()
  final MediaAssetType type;
  @SafeStringJsonConverter()
  final String publicUrl;
  @SafeStringJsonConverter()
  final String filename;
  @SafeStringJsonConverter()
  final String contentType;
  @SafeIntJsonConverter()
  final int byteSize;
  @SafeIntJsonConverter()
  final int width;
  @SafeIntJsonConverter()
  final int height;
  @SafeIntJsonConverter()
  final int durationSeconds;
  @JsonKey(defaultValue: false)
  final bool cover;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;

  /// 获取显示名称
  String get displayName {
    if (filename.isNotEmpty) return filename;
    if (publicUrl.isNotEmpty) return publicUrl;
    return id;
  }

  factory AdminMediaItem.fromJson(Map<String, dynamic> json) =>
      _$AdminMediaItemFromJson(json);

  Map<String, dynamic> toJson() => _$AdminMediaItemToJson(this);
}

/// 管理后台媒体草稿模型
/// 保留手写 toJson：包含 .trim() 和条件逻辑
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

/// 管理后台知识库文档项模型
@JsonSerializable()
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

  @SafeStringJsonConverter()
  final String id;
  @SafeStringJsonConverter()
  final String title;
  @KnowledgeSourceTypeJsonConverter()
  final KnowledgeSourceType sourceType;
  @SafeStringJsonConverter()
  final String sourceRef;
  @SafeStringJsonConverter()
  final String body;
  @JsonKey(defaultValue: true)
  final bool enabled;
  @SafeDateTimeJsonConverter()
  final DateTime createdAt;
  @SafeDateTimeJsonConverter()
  final DateTime updatedAt;

  factory AdminKnowledgeDocItem.fromJson(Map<String, dynamic> json) =>
      _$AdminKnowledgeDocItemFromJson(json);

  Map<String, dynamic> toJson() => _$AdminKnowledgeDocItemToJson(this);
}

/// 管理后台知识库文档草稿模型
/// 保留手写 toJson：包含 .trim() 调用
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

/// 管理后台知识库文档查询参数
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

  AdminKnowledgeDocQuery copyWith({
    String? query,
    bool? enabled,
    bool clearEnabled = false,
    int? page,
    int? size,
  }) {
    return AdminKnowledgeDocQuery(
      query: query ?? this.query,
      enabled: clearEnabled ? null : (enabled ?? this.enabled),
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }

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

/// 重新索引结果
class ReindexResult {
  const ReindexResult({
    required this.successCount,
    required this.failCount,
    required this.totalCount,
  });

  final int successCount;
  final int failCount;
  final int totalCount;

  bool get isAllSuccess => failCount == 0;

  factory ReindexResult.fromJson(Map<String, dynamic> json) {
    return ReindexResult(
      successCount: json['successCount'] as int? ?? 0,
      failCount: json['failCount'] as int? ?? 0,
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }
}

/// 知识库索引状态
class IndexStatus {
  const IndexStatus({
    required this.totalChunks,
    required this.chunksWithEmbedding,
    required this.failedChunks,
  });

  final int totalChunks;
  final int chunksWithEmbedding;
  final int failedChunks;

  /// 是否需要重新索引
  bool get needsReindex => failedChunks > 0;

  /// 索引完成率（0-100）
  double get indexRate {
    if (totalChunks == 0) return 100.0;
    return chunksWithEmbedding / totalChunks * 100;
  }

  factory IndexStatus.fromJson(Map<String, dynamic> json) {
    return IndexStatus(
      totalChunks: json['totalChunks'] as int? ?? 0,
      chunksWithEmbedding: json['chunksWithEmbedding'] as int? ?? 0,
      failedChunks: json['failedChunks'] as int? ?? 0,
    );
  }
}
