// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminCommentItem _$AdminCommentItemFromJson(
  Map<String, dynamic> json,
) => AdminCommentItem(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  contentId: const SafeStringJsonConverter().fromJson(json['contentId']),
  contentTitle: const SafeStringJsonConverter().fromJson(json['contentTitle']),
  userId: const SafeStringJsonConverter().fromJson(json['userId']),
  userNickname: const SafeStringJsonConverter().fromJson(json['userNickname']),
  userEmail: const SafeStringJsonConverter().fromJson(json['userEmail']),
  status: const AdminCommentStatusJsonConverter().fromJson(
    json['status'] as String,
  ),
  body: const SafeStringJsonConverter().fromJson(json['body']),
  createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
  updatedAt: const SafeDateTimeJsonConverter().fromJson(json['updatedAt']),
);

Map<String, dynamic> _$AdminCommentItemToJson(
  AdminCommentItem instance,
) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'contentId': const SafeStringJsonConverter().toJson(instance.contentId),
  'contentTitle': const SafeStringJsonConverter().toJson(instance.contentTitle),
  'userId': const SafeStringJsonConverter().toJson(instance.userId),
  'userNickname': const SafeStringJsonConverter().toJson(instance.userNickname),
  'userEmail': const SafeStringJsonConverter().toJson(instance.userEmail),
  'status': const AdminCommentStatusJsonConverter().toJson(instance.status),
  'body': const SafeStringJsonConverter().toJson(instance.body),
  'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
  'updatedAt': const SafeDateTimeJsonConverter().toJson(instance.updatedAt),
};
