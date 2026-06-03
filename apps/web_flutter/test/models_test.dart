// 模型解析单元测试
// 验证 ContentType、ContentListQuery、PageResult、AuditLogItem、AuditLogQuery 等模型的正确性
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/models.dart';

void main() {
  /// ContentType 测试组
  /// 验证标签文本、API 值和解析逻辑
  group('ContentType', () {
    test('label returns correct text', () {
      expect(ContentType.text.label, '文本');
      expect(ContentType.article.label, '图文');
      expect(ContentType.image.label, '图片');
      expect(ContentType.video.label, '视频');
    });

    test('apiValue returns correct string', () {
      expect(ContentType.text.apiValue, 'TEXT');
      expect(ContentType.article.apiValue, 'ARTICLE');
      expect(ContentType.image.apiValue, 'IMAGE');
      expect(ContentType.video.apiValue, 'VIDEO');
    });

    test('fromApi parses correctly', () {
      expect(ContentType.fromApi('TEXT'), ContentType.text);
      expect(ContentType.fromApi('ARTICLE'), ContentType.article);
      expect(ContentType.fromApi('IMAGE'), ContentType.image);
      expect(ContentType.fromApi('VIDEO'), ContentType.video);
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
