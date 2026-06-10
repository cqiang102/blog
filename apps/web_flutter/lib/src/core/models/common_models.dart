// 通用数据模型
// 包含分页结果、标签、友情链接、媒体等

import 'enums.dart';
import 'helpers.dart';

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

/// 标签项模型
class TagItem {
  const TagItem({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 从 JSON 创建实例
  factory TagItem.fromJson(Map<String, dynamic> json) {
    return TagItem(
      id: jsonString(json['id']),
      name: jsonString(json['name']),
      slug: jsonString(json['slug']),
      description: jsonString(json['description']),
      createdAt: json['createdAt'] == null ? null : jsonDate(json['createdAt']),
      updatedAt: json['updatedAt'] == null ? null : jsonDate(json['updatedAt']),
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

  final String id;
  final String name;
  final String intro;
  final String avatarUrl;
  final String siteUrl;
  final bool visible;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 从 JSON 创建实例
  factory FriendLink.fromJson(Map<String, dynamic> json) {
    return FriendLink(
      id: jsonString(json['id']),
      name: jsonString(json['name']),
      intro: jsonString(json['intro']),
      avatarUrl: jsonString(json['avatarUrl']),
      siteUrl: jsonString(json['siteUrl']),
      visible: json['visible'] != false,
      sortOrder: jsonInt(json['sortOrder']),
      createdAt: json['createdAt'] == null ? null : jsonDate(json['createdAt']),
      updatedAt: json['updatedAt'] == null ? null : jsonDate(json['updatedAt']),
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

  /// 获取显示名称
  String get displayName {
    if (filename.isNotEmpty) return filename;
    if (publicUrl.isNotEmpty) return publicUrl;
    return id;
  }

  /// 从 JSON 创建实例
  factory AdminMediaItem.fromJson(Map<String, dynamic> json) {
    return AdminMediaItem(
      id: jsonString(json['id']),
      contentId: jsonString(json['contentId']),
      contentTitle: jsonString(json['contentTitle']),
      type: MediaAssetType.fromApi(jsonString(json['type'])),
      publicUrl: jsonString(json['publicUrl']),
      filename: jsonString(json['filename']),
      contentType: jsonString(json['contentType']),
      byteSize: jsonInt(json['byteSize']),
      width: jsonInt(json['width']),
      height: jsonInt(json['height']),
      durationSeconds: jsonInt(json['durationSeconds']),
      cover: json['cover'] == true,
      createdAt: jsonDate(json['createdAt']),
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

  /// 从 JSON 创建实例
  factory AdminKnowledgeDocItem.fromJson(Map<String, dynamic> json) {
    return AdminKnowledgeDocItem(
      id: jsonString(json['id']),
      title: jsonString(json['title']),
      sourceType: KnowledgeSourceType.fromApi(jsonString(json['sourceType'])),
      sourceRef: jsonString(json['sourceRef']),
      body: jsonString(json['body']),
      enabled: json['enabled'] != false,
      createdAt: jsonDate(json['createdAt']),
      updatedAt: jsonDate(json['updatedAt']),
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
