import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/admin/admin_widgets.dart';
import 'package:personal_blog_web/src/features/admin/tabs/ai_chat_admin_tab.dart';
import 'package:personal_blog_web/src/features/admin/tabs/audit_log_admin_tab.dart';
import 'package:personal_blog_web/src/features/admin/tabs/interaction_admin_tab.dart';
import 'package:personal_blog_web/src/features/admin/tabs/knowledge_admin_tab.dart';
import 'package:personal_blog_web/src/features/admin/tabs/user_admin_tab.dart';
import 'package:personal_blog_web/src/state/state.dart';
import 'package:personal_blog_web/src/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _date = DateTime.utc(2026, 6, 26, 3, 27);

PageResult<T> _page<T>(List<T> items) =>
    PageResult<T>(items: items, page: 0, size: 50, total: items.length);

final _likes = _page([
  AdminLikeItem(
    id: 'like-1',
    contentId: 'content-1',
    contentTitle: '一组生活照片',
    userId: 'user-1',
    userNickname: '沐凉',
    userEmail: 'author@example.com',
    createdAt: _date,
  ),
]);

final _views = _page([
  AdminViewRecordItem(
    id: 'view-1',
    contentId: 'content-1',
    contentTitle: '一只岁岁',
    userId: 'user-1',
    userNickname: '沐凉',
    userEmail: 'author@example.com',
    anonymousId: 'IKIXzYzOPETMHOJV4txz7343g9cSQXdy8oKPJ7hPnlw',
    ipHash: 'hash',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 Chrome/149.0.0.0 Safari/537.36',
    createdAt: _date,
  ),
]);

final _users = _page([
  AdminUserItem(
    id: 'user-1',
    email: 'author@example.com',
    nickname: '沐凉',
    avatarUrl: '',
    bio: '一入后端深似海，从此对象是路人。',
    blogUrl: 'https://blog.example.com',
    role: AdminUserRole.user,
    status: AdminUserStatus.active,
    createdAt: _date,
    updatedAt: _date,
  ),
  AdminUserItem(
    id: 'user-2',
    email: 'disabled@example.com',
    nickname: '已停用用户',
    avatarUrl: '',
    bio: '',
    blogUrl: '',
    role: AdminUserRole.user,
    status: AdminUserStatus.disabled,
    createdAt: _date,
    updatedAt: _date,
  ),
]);

final _chats = _page([
  AdminAiChatSessionItem(
    id: 'chat-1',
    userId: 'user-1',
    userNickname: '沐凉',
    userEmail: 'author@example.com',
    title: '新会话',
    messageCount: 8,
    lastMessage: '我是博客的 AI 助手，主要技术能力包括信息检索与内容总结。',
    createdAt: _date,
    updatedAt: _date,
  ),
]);

final _knowledgeDocs = _page([
  AdminKnowledgeDocItem(
    id: 'doc-1',
    title: '我的个人简介',
    sourceType: KnowledgeSourceType.manual,
    sourceRef: 'https://blog.example.com',
    body: '我是沐凉，一名 Java 开发工程师。这里记录技术与生活。',
    enabled: true,
    createdAt: _date,
    updatedAt: _date,
  ),
]);

final _logs = _page([
  AuditLogItem(
    id: 'log-1',
    actorUserId: 'user-1',
    actorNickname: '沐凉',
    action: 'READ',
    resourceType: 'KNOWLEDGE',
    resourceId: 'doc-1',
    createdAt: _date,
  ),
]);

Future<void> _pumpTab(
  WidgetTester tester, {
  required Widget tab,
  required Widget Function(Widget child) scopeBuilder,
  Size size = const Size(1000, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    scopeBuilder(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(body: tab),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectDenseFilter(WidgetTester tester) {
  expect(find.byType(AdminFilterBar), findsOneWidget);
  expect(
    tester.getSize(find.byType(AdminFilterBar)).height,
    lessThanOrEqualTo(56),
  );
  expect(tester.takeException(), isNull);
}

void _expectTrailingAction(WidgetTester tester, String label) {
  expect(tester.getCenter(find.text(label).first).dx, greaterThan(800));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('like and view actions stay anchored to the card edge', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      tab: const AdminLikeTab(),
      scopeBuilder: (child) => ProviderScope(
        key: UniqueKey(),
        overrides: [
          adminLikesProvider.overrideWith((ref, query) async => _likes),
        ],
        child: child,
      ),
    );
    _expectDenseFilter(tester);
    _expectTrailingAction(tester, '删除');
    await expectLater(
      find.byType(AdminLikeTab),
      matchesGoldenFile('goldens/admin_likes_1000.png'),
    );

    await _pumpTab(
      tester,
      tab: const AdminViewTab(),
      scopeBuilder: (child) => ProviderScope(
        key: UniqueKey(),
        overrides: [
          adminViewsProvider.overrideWith((ref, query) async => _views),
        ],
        child: child,
      ),
    );
    _expectDenseFilter(tester);
    _expectTrailingAction(tester, '删除');
    await expectLater(
      find.byType(AdminViewTab),
      matchesGoldenFile('goldens/admin_views_1000.png'),
    );
  });

  testWidgets('user and AI rows separate metadata from actions', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      tab: const AdminUserTab(),
      scopeBuilder: (child) => ProviderScope(
        key: UniqueKey(),
        overrides: [
          adminUsersProvider.overrideWith((ref, query) async => _users),
        ],
        child: child,
      ),
    );
    _expectDenseFilter(tester);
    _expectTrailingAction(tester, '编辑');
    expect(
      find.ancestor(
        of: find.text('禁用'),
        matching: find.bySubtype<TextButton>(),
      ),
      findsOneWidget,
    );
    await expectLater(
      find.byType(AdminUserTab),
      matchesGoldenFile('goldens/admin_users_1000.png'),
    );

    await _pumpTab(
      tester,
      tab: const AdminAiChatTab(),
      scopeBuilder: (child) => ProviderScope(
        key: UniqueKey(),
        overrides: [
          adminAiChatsProvider.overrideWith((ref, query) async => _chats),
        ],
        child: child,
      ),
    );
    _expectDenseFilter(tester);
    _expectTrailingAction(tester, '查看');
    await expectLater(
      find.byType(AdminAiChatTab),
      matchesGoldenFile('goldens/admin_ai_chats_1000.png'),
    );
  });

  testWidgets('knowledge and audit filters use the compact desktop density', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      tab: const AdminKnowledgeTab(),
      scopeBuilder: (child) => ProviderScope(
        key: UniqueKey(),
        overrides: [
          adminKnowledgeDocsProvider.overrideWith(
            (ref, query) async => _knowledgeDocs,
          ),
          knowledgeIndexStatusProvider.overrideWith(
            (ref) async => const IndexStatus(
              totalChunks: 20,
              chunksWithEmbedding: 20,
              failedChunks: 0,
            ),
          ),
        ],
        child: child,
      ),
    );
    _expectDenseFilter(tester);
    _expectTrailingAction(tester, '编辑');
    await expectLater(
      find.byType(AdminKnowledgeTab),
      matchesGoldenFile('goldens/admin_knowledge_1000.png'),
    );

    await _pumpTab(
      tester,
      tab: const AdminAuditLogTab(),
      scopeBuilder: (child) => ProviderScope(
        key: UniqueKey(),
        overrides: [
          adminAuditLogsProvider.overrideWith((ref, query) async => _logs),
        ],
        child: child,
      ),
    );
    _expectDenseFilter(tester);
    await expectLater(
      find.byType(AdminAuditLogTab),
      matchesGoldenFile('goldens/admin_audit_logs_1000.png'),
    );
  });

  testWidgets('dense filters stack without overflow on narrow screens', (
    tester,
  ) async {
    await _pumpTab(
      tester,
      tab: const AdminViewTab(),
      size: const Size(390, 844),
      scopeBuilder: (child) => ProviderScope(
        key: UniqueKey(),
        overrides: [
          adminViewsProvider.overrideWith((ref, query) async => _views),
        ],
        child: child,
      ),
    );
    expect(tester.takeException(), isNull);

    await _pumpTab(
      tester,
      tab: const AdminUserTab(),
      size: const Size(390, 844),
      scopeBuilder: (child) => ProviderScope(
        key: UniqueKey(),
        overrides: [
          adminUsersProvider.overrideWith((ref, query) async => _users),
        ],
        child: child,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
