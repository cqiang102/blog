// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminContentItem _$AdminContentItemFromJson(
  Map<String, dynamic> json,
) => AdminContentItem(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  title: const SafeStringJsonConverter().fromJson(json['title']),
  slug: const SafeStringJsonConverter().fromJson(json['slug']),
  type: const ContentTypeJsonConverter().fromJson(json['type'] as String),
  status: const ContentStatusJsonConverter().fromJson(json['status'] as String),
  summary: const SafeStringJsonConverter().fromJson(json['summary']),
  bodyMarkdown: const SafeStringJsonConverter().fromJson(json['bodyMarkdown']),
  pinned: json['pinned'] as bool? ?? false,
  coverMediaId: const SafeStringJsonConverter().fromJson(json['coverMediaId']),
  coverUrl: const SafeStringJsonConverter().fromJson(json['coverUrl']),
  mediaCount: const SafeIntJsonConverter().fromJson(json['mediaCount']),
  mediaUrls: const SafeStringListJsonConverter().fromJson(json['mediaUrls']),
  likeCount: const SafeIntJsonConverter().fromJson(json['likeCount']),
  viewCount: const SafeIntJsonConverter().fromJson(json['viewCount']),
  commentCount: const SafeIntJsonConverter().fromJson(json['commentCount']),
  publishedAt: const SafeDateTimeJsonConverter().fromJson(json['publishedAt']),
  tags: (json['tags'] as List<dynamic>)
      .map((e) => TagItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  deletedAt: const NullableSafeDateTimeJsonConverter().fromJson(
    json['deletedAt'],
  ),
);

Map<String, dynamic> _$AdminContentItemToJson(
  AdminContentItem instance,
) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'title': const SafeStringJsonConverter().toJson(instance.title),
  'slug': const SafeStringJsonConverter().toJson(instance.slug),
  'type': const ContentTypeJsonConverter().toJson(instance.type),
  'status': const ContentStatusJsonConverter().toJson(instance.status),
  'summary': const SafeStringJsonConverter().toJson(instance.summary),
  'bodyMarkdown': const SafeStringJsonConverter().toJson(instance.bodyMarkdown),
  'pinned': instance.pinned,
  'coverMediaId': const SafeStringJsonConverter().toJson(instance.coverMediaId),
  'coverUrl': const SafeStringJsonConverter().toJson(instance.coverUrl),
  'mediaCount': const SafeIntJsonConverter().toJson(instance.mediaCount),
  'mediaUrls': const SafeStringListJsonConverter().toJson(instance.mediaUrls),
  'likeCount': const SafeIntJsonConverter().toJson(instance.likeCount),
  'viewCount': const SafeIntJsonConverter().toJson(instance.viewCount),
  'commentCount': const SafeIntJsonConverter().toJson(instance.commentCount),
  'publishedAt': const SafeDateTimeJsonConverter().toJson(instance.publishedAt),
  'deletedAt': const NullableSafeDateTimeJsonConverter().toJson(
    instance.deletedAt,
  ),
  'tags': instance.tags,
};
