// 模型解析单元测试
// 验证 ContentType、ContentListQuery、PageResult、AuditLogItem、AuditLogQuery、
// UserProfile、AuthSession、BlogContent、Recommendations、AiQuota、AiChatReply、
// FriendLink、TagItem 等模型的正确性
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/models.dart';

void main() {
  /// ContentType 测试组
  /// 验证标签文本、API 值和解析逻辑
  group('ContentType', () {
    test('label returns correct text', () {
      expect(ContentType.markdown.label, '文章');
      expect(ContentType.image.label, '图片');
      expect(ContentType.video.label, '视频');
    });

    test('apiValue returns correct string', () {
      expect(ContentType.markdown.apiValue, 'ARTICLE');
      expect(ContentType.image.apiValue, 'IMAGE');
      expect(ContentType.video.apiValue, 'VIDEO');
    });

    test('fromApi parses correctly', () {
      expect(ContentType.fromApi('ARTICLE'), ContentType.markdown);
      expect(ContentType.fromApi('IMAGE'), ContentType.image);
      expect(ContentType.fromApi('VIDEO'), ContentType.video);
      expect(ContentType.fromApi('TEXT'), ContentType.markdown);
      expect(ContentType.fromApi(null), ContentType.markdown);
    });
  });

  /// ContentStatus 测试组
  group('ContentStatus', () {
    test('label returns correct text', () {
      expect(ContentStatus.draft.label, '草稿');
      expect(ContentStatus.published.label, '已发布');
      expect(ContentStatus.archived.label, '已归档');
    });

    test('fromApi parses correctly', () {
      expect(ContentStatus.fromApi('DRAFT'), ContentStatus.draft);
      expect(ContentStatus.fromApi('PUBLISHED'), ContentStatus.published);
      expect(ContentStatus.fromApi('ARCHIVED'), ContentStatus.archived);
      expect(ContentStatus.fromApi(null), ContentStatus.draft);
    });
  });

  /// ContentListQuery 测试组
  /// 验证默认值和相等性判断
  group('ContentListQuery', () {
    test('creates with default values', () {
      const query = ContentListQuery();
      expect(query.query, '');
      expect(query.tag, isNull);
      expect(query.type, isNull);
      expect(query.page, 0);
      expect(query.size, 10);
    });

    test('equality works correctly', () {
      const query1 = ContentListQuery(query: 'test', page: 0);
      const query2 = ContentListQuery(query: 'test', page: 0);
      const query3 = ContentListQuery(query: 'other', page: 0);

      expect(query1, equals(query2));
      expect(query1, isNot(equals(query3)));
    });
  });

  /// PageResult 测试组
  /// 验证分页结果的创建和字段值
  group('PageResult', () {
    test('creates correctly', () {
      const result = PageResult<String>(
        items: ['a', 'b', 'c'],
        page: 0,
        size: 10,
        total: 3,
      );

      expect(result.items, hasLength(3));
      expect(result.page, 0);
      expect(result.size, 10);
      expect(result.total, 3);
    });
  });

  /// UserProfile 测试组
  group('UserProfile', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'user-001',
        'email': 'test@example.com',
        'nickname': '测试用户',
        'role': 'ADMIN',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'bio': '个人简介',
        'blogUrl': 'https://blog.example.com',
        'hasPassword': true,
      };

      final user = UserProfile.fromJson(json);

      expect(user.id, 'user-001');
      expect(user.email, 'test@example.com');
      expect(user.nickname, '测试用户');
      expect(user.role, 'ADMIN');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.bio, '个人简介');
      expect(user.blogUrl, 'https://blog.example.com');
      expect(user.hasPassword, true);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'user-002',
        'email': 'test2@example.com',
        'nickname': '用户2',
      };

      final user = UserProfile.fromJson(json);

      expect(user.role, 'USER');
      expect(user.avatarUrl, isNull);
      expect(user.bio, isNull);
      expect(user.blogUrl, isNull);
      expect(user.hasPassword, false);
    });

    test('toJson roundtrip', () {
      const user = UserProfile(
        id: 'user-003',
        email: 'test3@example.com',
        nickname: '用户3',
        role: 'USER',
      );

      final json = user.toJson();
      expect(json['id'], 'user-003');
      expect(json['email'], 'test3@example.com');
      expect(json['nickname'], '用户3');
      expect(json['role'], 'USER');
    });
  });

  /// AuthSession 测试组
  group('AuthSession', () {
    test('fromJson parses correctly', () {
      final json = {
        'accessToken': 'access-token-123',
        'refreshToken': 'refresh-token-456',
        'expiresAt': '2026-06-05T12:00:00Z',
        'user': {
          'id': 'user-001',
          'email': 'test@example.com',
          'nickname': '测试',
          'role': 'USER',
        },
      };

      final session = AuthSession.fromJson(json);

      expect(session.accessToken, 'access-token-123');
      expect(session.refreshToken, 'refresh-token-456');
      expect(session.user.id, 'user-001');
      expect(session.user.email, 'test@example.com');
    });
  });

  /// BlogContent 测试组
  group('BlogContent', () {
    test('fromSummaryJson parses correctly', () {
      final json = {
        'id': 'content-001',
        'title': '测试文章',
        'slug': 'test-article',
        'type': 'ARTICLE',
        'summary': '摘要',
        'coverUrl': 'https://example.com/cover.jpg',
        'tags': ['Flutter', 'Dart'],
        'pinned': true,
        'likeCount': 42,
        'publishedAt': '2026-06-01T00:00:00Z',
      };

      final content = BlogContent.fromSummaryJson(json);

      expect(content.id, 'content-001');
      expect(content.title, '测试文章');
      expect(content.type, ContentType.markdown);
      expect(content.tags, ['Flutter', 'Dart']);
      expect(content.pinned, true);
      expect(content.likeCount, 42);
      expect(content.markdown, '');
      expect(content.mediaUrls, isEmpty);
    });

    test('fromDetailJson parses correctly', () {
      final json = {
        'id': 'content-002',
        'title': '详情文章',
        'slug': 'detail-article',
        'type': 'IMAGE',
        'summary': '图片摘要',
        'coverUrl': '',
        'tags': ['生活'],
        'pinned': false,
        'likeCount': 10,
        'viewCount': 100,
        'commentCount': 5,
        'likedByCurrentUser': true,
        'publishedAt': '2026-05-20T00:00:00Z',
        'bodyMarkdown': '# 标题\n\n正文',
        'mediaAssets': [
          {'publicUrl': 'https://example.com/img1.jpg'},
          {'publicUrl': 'https://example.com/img2.jpg'},
        ],
      };

      final content = BlogContent.fromDetailJson(json);

      expect(content.id, 'content-002');
      expect(content.type, ContentType.image);
      expect(content.markdown, '# 标题\n\n正文');
      expect(content.mediaUrls, hasLength(2));
      expect(content.likedByCurrentUser, true);
      expect(content.viewCount, 100);
      expect(content.commentCount, 5);
    });

    test('fromSummaryJson handles missing fields gracefully', () {
      final json = <String, dynamic>{};

      final content = BlogContent.fromSummaryJson(json);

      expect(content.id, '');
      expect(content.title, '');
      expect(content.type, ContentType.markdown);
      expect(content.tags, isEmpty);
      expect(content.likeCount, 0);
    });
  });

  /// Recommendations 测试组
  group('Recommendations', () {
    test('fromJson parses correctly', () {
      final json = {
        'pinned': [
          {
            'id': '1',
            'title': '置顶',
            'type': 'ARTICLE',
            'summary': '',
            'coverUrl': '',
            'tags': [],
            'pinned': true,
            'likeCount': 0,
            'publishedAt': '2026-06-01T00:00:00Z',
          },
        ],
        'latest': [],
        'mostLiked': [],
      };

      final rec = Recommendations.fromJson(json);

      expect(rec.pinned, hasLength(1));
      expect(rec.latest, isEmpty);
      expect(rec.mostLiked, isEmpty);
    });
  });

  /// AiQuota 测试组
  group('AiQuota', () {
    test('fromJson parses correctly', () {
      final json = {'dailyLimit': 10, 'used': 3};

      final quota = AiQuota.fromJson(json);

      expect(quota.dailyLimit, 10);
      expect(quota.used, 3);
      expect(quota.remaining, 7);
    });
  });

  /// AiChatReply 测试组
  group('AiChatReply', () {
    test('fromJson parses correctly', () {
      final json = {
        'sessionId': 'session-001',
        'answer': '你好！',
        'remainingQuestions': 9,
        'remainingMessages': 35,
      };

      final reply = AiChatReply.fromJson(json);

      expect(reply.sessionId, 'session-001');
      expect(reply.answer, '你好！');
      expect(reply.remainingQuestions, 9);
      expect(reply.remainingMessages, 35);
    });
  });

  /// AiSessionItem 测试组
  group('AiSessionItem', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'session-001',
        'title': '新会话',
        'messageCount': 6,
        'createdAt': '2026-06-01T00:00:00Z',
        'updatedAt': '2026-06-01T01:00:00Z',
      };

      final session = AiSessionItem.fromJson(json);

      expect(session.id, 'session-001');
      expect(session.title, '新会话');
      expect(session.messageCount, 6);
    });
  });

  /// FriendLink 测试组
  group('FriendLink', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'friend-001',
        'name': '小栈',
        'intro': '前端、摄影',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'siteUrl': 'https://example.com',
        'visible': true,
        'sortOrder': 1,
      };

      final friend = FriendLink.fromJson(json);

      expect(friend.id, 'friend-001');
      expect(friend.name, '小栈');
      expect(friend.intro, '前端、摄影');
      expect(friend.siteUrl, 'https://example.com');
      expect(friend.visible, true);
      expect(friend.sortOrder, 1);
    });

    test('fromJson defaults visible to true', () {
      final json = {
        'id': 'friend-002',
        'name': '测试',
        'intro': '',
        'avatarUrl': '',
        'siteUrl': 'https://example.org',
      };

      final friend = FriendLink.fromJson(json);
      expect(friend.visible, true);
    });
  });

  /// TagItem 测试组
  group('TagItem', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'tag-001',
        'name': 'Flutter',
        'slug': 'flutter',
        'description': 'Flutter 框架',
      };

      final tag = TagItem.fromJson(json);

      expect(tag.id, 'tag-001');
      expect(tag.name, 'Flutter');
      expect(tag.slug, 'flutter');
      expect(tag.description, 'Flutter 框架');
    });

    test('fromJson handles missing description', () {
      final json = {
        'id': 'tag-002',
        'name': 'Dart',
        'slug': 'dart',
      };

      final tag = TagItem.fromJson(json);
      expect(tag.description, '');
    });
  });

  /// AuditLogItem 测试组
  /// 验证审计日志的 JSON 解析，包括完整字段和空字段处理
  group('AuditLogItem', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'actorUserId': '223e4567-e89b-12d3-a456-426614174000',
        'actorNickname': '管理员',
        'action': 'CREATE',
        'resourceType': 'CONTENT',
        'resourceId': '323e4567-e89b-12d3-a456-426614174000',
        'detail': '{"title": "test"}',
        'createdAt': '2026-06-01T00:00:00Z',
      };

      final item = AuditLogItem.fromJson(json);

      expect(item.id, '123e4567-e89b-12d3-a456-426614174000');
      expect(item.actorNickname, '管理员');
      expect(item.action, 'CREATE');
      expect(item.resourceType, 'CONTENT');
      expect(item.detail, '{"title": "test"}');
    });

    test('fromJson handles null fields', () {
      final json = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'action': 'DELETE',
        'resourceType': 'USER',
        'createdAt': '2026-06-01T00:00:00Z',
      };

      final item = AuditLogItem.fromJson(json);

      expect(item.actorUserId, isNull);
      expect(item.actorNickname, isNull);
      expect(item.resourceId, isNull);
      expect(item.detail, isNull);
    });
  });

  /// AuditLogQuery 测试组
  /// 验证审计日志查询的默认值和相等性判断
  group('AuditLogQuery', () {
    test('creates with default values', () {
      const query = AuditLogQuery();
      expect(query.action, isNull);
      expect(query.resourceType, isNull);
      expect(query.page, 0);
      expect(query.size, 50);
    });

    test('equality works correctly', () {
      const query1 = AuditLogQuery(action: 'CREATE', resourceType: 'CONTENT');
      const query2 = AuditLogQuery(action: 'CREATE', resourceType: 'CONTENT');
      const query3 = AuditLogQuery(action: 'DELETE', resourceType: 'CONTENT');

      expect(query1, equals(query2));
      expect(query1, isNot(equals(query3)));
    });
  });
}
