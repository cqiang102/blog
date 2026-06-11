// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminLikeItem _$AdminLikeItemFromJson(
  Map<String, dynamic> json,
) => AdminLikeItem(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  contentId: const SafeStringJsonConverter().fromJson(json['contentId']),
  contentTitle: const SafeStringJsonConverter().fromJson(json['contentTitle']),
  userId: const SafeStringJsonConverter().fromJson(json['userId']),
  userNickname: const SafeStringJsonConverter().fromJson(json['userNickname']),
  userEmail: const SafeStringJsonConverter().fromJson(json['userEmail']),
  createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
);

Map<String, dynamic> _$AdminLikeItemToJson(
  AdminLikeItem instance,
) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'contentId': const SafeStringJsonConverter().toJson(instance.contentId),
  'contentTitle': const SafeStringJsonConverter().toJson(instance.contentTitle),
  'userId': const SafeStringJsonConverter().toJson(instance.userId),
  'userNickname': const SafeStringJsonConverter().toJson(instance.userNickname),
  'userEmail': const SafeStringJsonConverter().toJson(instance.userEmail),
  'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
};

AdminViewRecordItem _$AdminViewRecordItemFromJson(
  Map<String, dynamic> json,
) => AdminViewRecordItem(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  contentId: const SafeStringJsonConverter().fromJson(json['contentId']),
  contentTitle: const SafeStringJsonConverter().fromJson(json['contentTitle']),
  userId: const SafeStringJsonConverter().fromJson(json['userId']),
  userNickname: const SafeStringJsonConverter().fromJson(json['userNickname']),
  userEmail: const SafeStringJsonConverter().fromJson(json['userEmail']),
  anonymousId: const SafeStringJsonConverter().fromJson(json['anonymousId']),
  ipHash: const SafeStringJsonConverter().fromJson(json['ipHash']),
  userAgent: const SafeStringJsonConverter().fromJson(json['userAgent']),
  createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
);

Map<String, dynamic> _$AdminViewRecordItemToJson(
  AdminViewRecordItem instance,
) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'contentId': const SafeStringJsonConverter().toJson(instance.contentId),
  'contentTitle': const SafeStringJsonConverter().toJson(instance.contentTitle),
  'userId': const SafeStringJsonConverter().toJson(instance.userId),
  'userNickname': const SafeStringJsonConverter().toJson(instance.userNickname),
  'userEmail': const SafeStringJsonConverter().toJson(instance.userEmail),
  'anonymousId': const SafeStringJsonConverter().toJson(instance.anonymousId),
  'ipHash': const SafeStringJsonConverter().toJson(instance.ipHash),
  'userAgent': const SafeStringJsonConverter().toJson(instance.userAgent),
  'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
};

AdminUserItem _$AdminUserItemFromJson(Map<String, dynamic> json) =>
    AdminUserItem(
      id: const SafeStringJsonConverter().fromJson(json['id']),
      email: const SafeStringJsonConverter().fromJson(json['email']),
      nickname: const SafeStringJsonConverter().fromJson(json['nickname']),
      avatarUrl: const SafeStringJsonConverter().fromJson(json['avatarUrl']),
      bio: const SafeStringJsonConverter().fromJson(json['bio']),
      blogUrl: const SafeStringJsonConverter().fromJson(json['blogUrl']),
      role: const AdminUserRoleJsonConverter().fromJson(json['role'] as String),
      status: const AdminUserStatusJsonConverter().fromJson(
        json['status'] as String,
      ),
      createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
      updatedAt: const SafeDateTimeJsonConverter().fromJson(json['updatedAt']),
    );

Map<String, dynamic> _$AdminUserItemToJson(AdminUserItem instance) =>
    <String, dynamic>{
      'id': const SafeStringJsonConverter().toJson(instance.id),
      'email': const SafeStringJsonConverter().toJson(instance.email),
      'nickname': const SafeStringJsonConverter().toJson(instance.nickname),
      'avatarUrl': const SafeStringJsonConverter().toJson(instance.avatarUrl),
      'bio': const SafeStringJsonConverter().toJson(instance.bio),
      'blogUrl': const SafeStringJsonConverter().toJson(instance.blogUrl),
      'role': const AdminUserRoleJsonConverter().toJson(instance.role),
      'status': const AdminUserStatusJsonConverter().toJson(instance.status),
      'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
      'updatedAt': const SafeDateTimeJsonConverter().toJson(instance.updatedAt),
    };

AdminDashboard _$AdminDashboardFromJson(Map<String, dynamic> json) =>
    AdminDashboard(
      contents: const SafeIntJsonConverter().fromJson(json['contents']),
      media: const SafeIntJsonConverter().fromJson(json['media']),
      friends: const SafeIntJsonConverter().fromJson(json['friends']),
      users: const SafeIntJsonConverter().fromJson(json['users']),
      comments: const SafeIntJsonConverter().fromJson(json['comments']),
      likes: const SafeIntJsonConverter().fromJson(json['likes']),
      views: const SafeIntJsonConverter().fromJson(json['views']),
      aiChats: const SafeIntJsonConverter().fromJson(json['aiChats']),
      knowledgeDocs: const SafeIntJsonConverter().fromJson(
        json['knowledgeDocs'],
      ),
    );

Map<String, dynamic> _$AdminDashboardToJson(
  AdminDashboard instance,
) => <String, dynamic>{
  'contents': const SafeIntJsonConverter().toJson(instance.contents),
  'media': const SafeIntJsonConverter().toJson(instance.media),
  'friends': const SafeIntJsonConverter().toJson(instance.friends),
  'users': const SafeIntJsonConverter().toJson(instance.users),
  'comments': const SafeIntJsonConverter().toJson(instance.comments),
  'likes': const SafeIntJsonConverter().toJson(instance.likes),
  'views': const SafeIntJsonConverter().toJson(instance.views),
  'aiChats': const SafeIntJsonConverter().toJson(instance.aiChats),
  'knowledgeDocs': const SafeIntJsonConverter().toJson(instance.knowledgeDocs),
};

AuditLogItem _$AuditLogItemFromJson(Map<String, dynamic> json) => AuditLogItem(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  action: const SafeStringJsonConverter().fromJson(json['action']),
  resourceType: const SafeStringJsonConverter().fromJson(json['resourceType']),
  actorUserId: const NullableStringJsonConverter().fromJson(
    json['actorUserId'],
  ),
  actorNickname: const NullableStringJsonConverter().fromJson(
    json['actorNickname'],
  ),
  resourceId: const NullableStringJsonConverter().fromJson(json['resourceId']),
  detail: const NullableStringJsonConverter().fromJson(json['detail']),
  createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
);

Map<String, dynamic> _$AuditLogItemToJson(
  AuditLogItem instance,
) => <String, dynamic>{
  'id': const SafeStringJsonConverter().toJson(instance.id),
  'actorUserId': const NullableStringJsonConverter().toJson(
    instance.actorUserId,
  ),
  'actorNickname': const NullableStringJsonConverter().toJson(
    instance.actorNickname,
  ),
  'action': const SafeStringJsonConverter().toJson(instance.action),
  'resourceType': const SafeStringJsonConverter().toJson(instance.resourceType),
  'resourceId': const NullableStringJsonConverter().toJson(instance.resourceId),
  'detail': const NullableStringJsonConverter().toJson(instance.detail),
  'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
};

UserActivity _$UserActivityFromJson(Map<String, dynamic> json) => UserActivity(
  id: const SafeStringJsonConverter().fromJson(json['id']),
  type: const SafeStringJsonConverter().fromJson(json['type']),
  contentId: const SafeStringJsonConverter().fromJson(json['contentId']),
  title: const SafeStringJsonConverter().fromJson(json['title']),
  createdAt: const SafeDateTimeJsonConverter().fromJson(json['createdAt']),
);

Map<String, dynamic> _$UserActivityToJson(UserActivity instance) =>
    <String, dynamic>{
      'id': const SafeStringJsonConverter().toJson(instance.id),
      'type': const SafeStringJsonConverter().toJson(instance.type),
      'contentId': const SafeStringJsonConverter().toJson(instance.contentId),
      'title': const SafeStringJsonConverter().toJson(instance.title),
      'createdAt': const SafeDateTimeJsonConverter().toJson(instance.createdAt),
    };
