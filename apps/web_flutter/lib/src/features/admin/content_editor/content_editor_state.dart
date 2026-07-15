import 'package:flutter/foundation.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/models.dart';

/// 编辑器编辑模式
enum EditorEditMode {
  /// 纯文本编辑
  source,

  /// 分屏模式：左侧编辑，右侧预览
  split,

  /// 纯预览模式
  preview;

  String get label {
    return switch (this) {
      EditorEditMode.source => '源码',
      EditorEditMode.split => '实时预览',
      EditorEditMode.preview => '纯预览',
    };
  }

  List<List<dynamic>> get icon {
    return switch (this) {
      EditorEditMode.source => HugeIcons.strokeRoundedCode,
      EditorEditMode.split => HugeIcons.strokeRoundedVerticalScrollPoint,
      EditorEditMode.preview => HugeIcons.strokeRoundedView,
    };
  }
}

/// 内容编辑器状态
@immutable
class ContentEditorState {
  const ContentEditorState({
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
    this.isUploading = false,
    this.uploadedCount = 0,
    this.uploadTotal = 0,
    this.isSubmitting = false,
    this.isSavingDraft = false,
    this.hasUnsavedChanges = false,
    this.lastLocalSavedAt,
    this.editMode = EditorEditMode.source,
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
  final bool isUploading;
  final int uploadedCount;
  final int uploadTotal;
  final bool isSubmitting;
  final bool isSavingDraft;
  final bool hasUnsavedChanges;
  final DateTime? lastLocalSavedAt;
  final EditorEditMode editMode;

  /// 从现有内容创建初始状态
  factory ContentEditorState.fromContent(AdminContentItem? content) {
    if (content == null) {
      return const ContentEditorState(
        title: '',
        slug: '',
        type: ContentType.markdown,
        status: ContentStatus.draft,
        summary: '',
        bodyMarkdown: '',
        pinned: false,
        tagSlugs: [],
      );
    }
    return ContentEditorState(
      title: content.title,
      slug: content.slug,
      type: content.type,
      status: content.status,
      summary: content.summary,
      bodyMarkdown: content.bodyMarkdown,
      pinned: content.pinned,
      tagSlugs: content.tags.map((tag) => tag.slug).toList(),
      mediaUrls: content.mediaUrls,
      coverUrl: content.coverUrl.trim().isEmpty ? null : content.coverUrl,
      publishedAt: content.publishedAt,
    );
  }

  /// 从草稿 JSON 创建状态
  factory ContentEditorState.fromJson(Map<String, dynamic> json) {
    return ContentEditorState(
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      type: ContentType.fromApi(json['type'] as String),
      status: ContentStatus.fromApi(json['status'] as String),
      summary: json['summary'] as String? ?? '',
      bodyMarkdown: json['bodyMarkdown'] as String? ?? '',
      pinned: json['pinned'] as bool? ?? false,
      tagSlugs: List<String>.from(json['tagSlugs'] ?? []),
      mediaUrls: List<String>.from(json['mediaUrls'] ?? []),
      coverUrl: switch (json['coverUrl']) {
        final String value when value.trim().isNotEmpty => value,
        _ => null,
      },
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'slug': slug,
      'type': type.apiValue,
      'status': status.apiValue,
      'summary': summary,
      'bodyMarkdown': bodyMarkdown,
      'pinned': pinned,
      'tagSlugs': tagSlugs,
      'mediaUrls': mediaUrls,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (publishedAt != null)
        'publishedAt': publishedAt!.toUtc().toIso8601String(),
    };
  }

  /// 转换为提交用的 Draft
  AdminContentDraft toDraft() {
    return AdminContentDraft(
      title: title,
      slug: slug,
      type: type,
      status: status,
      summary: summary,
      bodyMarkdown: bodyMarkdown,
      pinned: pinned,
      tagSlugs: [...tagSlugs]..sort(),
      mediaUrls: mediaUrls,
      coverUrl: coverUrl,
      publishedAt: publishedAt,
    );
  }

  /// 是否为媒体类型
  bool get isMediaType =>
      type == ContentType.image || type == ContentType.video;

  /// 是否为可预览类型（Markdown 类型）
  bool get isPreviewable => type == ContentType.markdown;

  double? get uploadProgress =>
      uploadTotal > 0 ? uploadedCount / uploadTotal : null;

  bool sameContentAs(ContentEditorState other) {
    return title == other.title &&
        slug == other.slug &&
        type == other.type &&
        status == other.status &&
        summary == other.summary &&
        bodyMarkdown == other.bodyMarkdown &&
        pinned == other.pinned &&
        setEquals(tagSlugs.toSet(), other.tagSlugs.toSet()) &&
        listEquals(mediaUrls, other.mediaUrls) &&
        coverUrl == other.coverUrl &&
        publishedAt == other.publishedAt;
  }

  /// 复制并修改状态
  ContentEditorState copyWith({
    String? title,
    String? slug,
    ContentType? type,
    ContentStatus? status,
    String? summary,
    String? bodyMarkdown,
    bool? pinned,
    List<String>? tagSlugs,
    List<String>? mediaUrls,
    String? coverUrl,
    bool clearCoverUrl = false,
    DateTime? publishedAt,
    bool clearPublishedAt = false,
    bool? isUploading,
    int? uploadedCount,
    int? uploadTotal,
    bool? isSubmitting,
    bool? isSavingDraft,
    bool? hasUnsavedChanges,
    DateTime? lastLocalSavedAt,
    bool clearLastLocalSavedAt = false,
    EditorEditMode? editMode,
  }) {
    return ContentEditorState(
      title: title ?? this.title,
      slug: slug ?? this.slug,
      type: type ?? this.type,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      bodyMarkdown: bodyMarkdown ?? this.bodyMarkdown,
      pinned: pinned ?? this.pinned,
      tagSlugs: tagSlugs ?? this.tagSlugs,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      coverUrl: clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
      publishedAt: clearPublishedAt ? null : (publishedAt ?? this.publishedAt),
      isUploading: isUploading ?? this.isUploading,
      uploadedCount: uploadedCount ?? this.uploadedCount,
      uploadTotal: uploadTotal ?? this.uploadTotal,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastLocalSavedAt: clearLastLocalSavedAt
          ? null
          : (lastLocalSavedAt ?? this.lastLocalSavedAt),
      editMode: editMode ?? this.editMode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentEditorState &&
        other.title == title &&
        other.slug == slug &&
        other.type == type &&
        other.status == status &&
        other.summary == summary &&
        other.bodyMarkdown == bodyMarkdown &&
        other.pinned == pinned &&
        listEquals(other.tagSlugs, tagSlugs) &&
        listEquals(other.mediaUrls, mediaUrls) &&
        other.coverUrl == coverUrl &&
        other.publishedAt == publishedAt &&
        other.isUploading == isUploading &&
        other.uploadedCount == uploadedCount &&
        other.uploadTotal == uploadTotal &&
        other.isSubmitting == isSubmitting &&
        other.isSavingDraft == isSavingDraft &&
        other.hasUnsavedChanges == hasUnsavedChanges &&
        other.lastLocalSavedAt == lastLocalSavedAt &&
        other.editMode == editMode;
  }

  @override
  int get hashCode {
    return Object.hash(
      title,
      slug,
      type,
      status,
      summary,
      bodyMarkdown,
      pinned,
      Object.hashAll(tagSlugs),
      Object.hashAll(mediaUrls),
      coverUrl,
      publishedAt,
      isUploading,
      uploadedCount,
      uploadTotal,
      isSubmitting,
      isSavingDraft,
      hasUnsavedChanges,
      lastLocalSavedAt,
      editMode,
    );
  }
}
