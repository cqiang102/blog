// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'common_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TagItem _$TagItemFromJson(Map<String, dynamic> json) => TagItem(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  name: const SafeStringJsonConverter().fromJson(json['name']),
  slug: const SafeStringJsonConverter().fromJson(json['slug']),
  description: json['description'] as String? ?? '',
  createdAt: const NullableSafeDateTimeJsonConverter().fromJson(
    json['createdAt'],
  ),
  updatedAt: const NullableSafeDateTimeJsonConverter().fromJson(
    json['updatedAt'],
  ),
);

Map<String, dynamic> _$TagItemToJson(TagItem instance) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'name': const SafeStringJsonConverter().toJson(instance.name),
  'slug': const SafeStringJsonConverter().toJson(instance.slug),
  'description': instance.description,
  'createdAt': const NullableSafeDateTimeJsonConverter().toJson(
    instance.createdAt,
  ),
  'updatedAt': const NullableSafeDateTimeJsonConverter().toJson(
    instance.updatedAt,
  ),
};

FriendLink _$FriendLinkFromJson(Map<String, dynamic> json) => FriendLink(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  name: const SafeStringJsonConverter().fromJson(json['name']),
  intro: const SafeStringJsonConverter().fromJson(json['intro']),
  avatarUrl: const SafeStringJsonConverter().fromJson(json['avatarUrl']),
  siteUrl: const SafeStringJsonConverter().fromJson(json['siteUrl']),
  visible: json['visible'] as bool? ?? true,
  sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
  createdAt: const NullableSafeDateTimeJsonConverter().fromJson(
    json['createdAt'],
  ),
  updatedAt: const NullableSafeDateTimeJsonConverter().fromJson(
    json['updatedAt'],
  ),
);

Map<String, dynamic> _$FriendLinkToJson(FriendLink instance) =>
    <String, dynamic>{
      'id': const SafeStringJsonConverter().toJson(instance.id),
      'name': const SafeStringJsonConverter().toJson(instance.name),
      'intro': const SafeStringJsonConverter().toJson(instance.intro),
      'avatarUrl': const SafeStringJsonConverter().toJson(instance.avatarUrl),
      'siteUrl': const SafeStringJsonConverter().toJson(instance.siteUrl),
      'visible': instance.visible,
      'sortOrder': instance.sortOrder,
      'createdAt': const NullableSafeDateTimeJsonConverter().toJson(
        instance.createdAt,
      ),
      'updatedAt': const NullableSafeDateTimeJsonConverter().toJson(
        instance.updatedAt,
      ),
    };

AdminMediaItem _$AdminMediaItemFromJson(
  Map<String, dynamic> json,
) => AdminMediaItem(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  contentId: const SafeStringJsonConverter().fromJson(json['contentId']),
  contentTitle: const SafeStringJsonConverter().fromJson(json['contentTitle']),
  type: const MediaAssetTypeJsonConverter().fromJson(json['type'] as String),
  publicUrl: const SafeStringJsonConverter().fromJson(json['publicUrl']),
  filename: const SafeStringJsonConverter().fromJson(json['filename']),
  contentType: const SafeStringJsonConverter().fromJson(json['contentType']),
  byteSize: const SafeIntJsonConverter().fromJson(json['byteSize']),
  width: const SafeIntJsonConverter().fromJson(json['width']),
  height: const SafeIntJsonConverter().fromJson(json['height']),
  durationSeconds: const SafeIntJsonConverter().fromJson(
    json['durationSeconds'],
  ),
  cover: json['cover'] as bool? ?? false,
  createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
);

Map<String, dynamic> _$AdminMediaItemToJson(
  AdminMediaItem instance,
) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'contentId': const SafeStringJsonConverter().toJson(instance.contentId),
  'contentTitle': const SafeStringJsonConverter().toJson(instance.contentTitle),
  'type': const MediaAssetTypeJsonConverter().toJson(instance.type),
  'publicUrl': const SafeStringJsonConverter().toJson(instance.publicUrl),
  'filename': const SafeStringJsonConverter().toJson(instance.filename),
  'contentType': const SafeStringJsonConverter().toJson(instance.contentType),
  'byteSize': const SafeIntJsonConverter().toJson(instance.byteSize),
  'width': const SafeIntJsonConverter().toJson(instance.width),
  'height': const SafeIntJsonConverter().toJson(instance.height),
  'durationSeconds': const SafeIntJsonConverter().toJson(
    instance.durationSeconds,
  ),
  'cover': instance.cover,
  'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
};

AdminKnowledgeDocItem _$AdminKnowledgeDocItemFromJson(
  Map<String, dynamic> json,
) => AdminKnowledgeDocItem(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  title: const SafeStringJsonConverter().fromJson(json['title']),
  sourceType: const KnowledgeSourceTypeJsonConverter().fromJson(
    json['sourceType'] as String,
  ),
  sourceRef: const SafeStringJsonConverter().fromJson(json['sourceRef']),
  body: const SafeStringJsonConverter().fromJson(json['body']),
  enabled: json['enabled'] as bool? ?? true,
  createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
  updatedAt: const SafeDateTimeJsonConverter().fromJson(json['updatedAt']),
);

Map<String, dynamic> _$AdminKnowledgeDocItemToJson(
  AdminKnowledgeDocItem instance,
) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'title': const SafeStringJsonConverter().toJson(instance.title),
  'sourceType': const KnowledgeSourceTypeJsonConverter().toJson(
    instance.sourceType,
  ),
  'sourceRef': const SafeStringJsonConverter().toJson(instance.sourceRef),
  'body': const SafeStringJsonConverter().toJson(instance.body),
  'enabled': instance.enabled,
  'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
  'updatedAt': const SafeDateTimeJsonConverter().toJson(instance.updatedAt),
};
