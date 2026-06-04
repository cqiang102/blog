import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
      EditorEditMode.split => '分屏',
      EditorEditMode.preview => '预览',
    };
  }

  IconData get icon {
    return switch (this) {
      EditorEditMode.source => Icons.code,
      EditorEditMode.split => Icons.vertical_split,
      EditorEditMode.preview => Icons.preview,
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
    this.isUploading = false,
    this.isSubmitting = false,
    this.hasUnsavedChanges = false,
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
  final bool isUploading;
  final bool isSubmitting;
  final bool hasUnsavedChanges;
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
      coverUrl: content.coverUrl,
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
      coverUrl: json['coverUrl'] as String?,
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
    );
  }

  /// 是否为媒体类型
  bool get isMediaType => type == ContentType.image || type == ContentType.video;

  /// 是否为可预览类型
  /// 是否为可预览类型（Markdown 类型）
  bool get isPreviewable => type == ContentType.markdown;

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
    bool? isUploading,
    bool? isSubmitting,
    bool? hasUnsavedChanges,
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
      isUploading: isUploading ?? this.isUploading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
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
        other.isUploading == isUploading &&
        other.isSubmitting == isSubmitting &&
        other.hasUnsavedChanges == hasUnsavedChanges &&
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
      isUploading,
      isSubmitting,
      hasUnsavedChanges,
      editMode,
    );
  }
}

/// 提交结果封装
/// 包含草稿数据和成功/失败回调，用于在 API 调用后清理状态
class ContentEditorSubmitResult {
  const ContentEditorSubmitResult({
    required this.draft,
    required this.onSuccess,
    required this.onFailure,
  });

  final AdminContentDraft draft;
  final VoidCallback onSuccess;
  final VoidCallback onFailure;
}
