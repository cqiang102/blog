import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/admin/admin_page.dart';
import 'package:personal_blog_web/src/features/admin/admin_tab_registry.dart';
import 'package:personal_blog_web/src/features/admin/admin_widgets.dart';
import 'package:personal_blog_web/src/features/admin/tabs/comment_admin_tab.dart';
import 'package:personal_blog_web/src/features/admin/tabs/content_admin_tab.dart';
import 'package:personal_blog_web/src/state/state.dart';
import 'package:personal_blog_web/src/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _contentPage = PageResult<AdminContentItem>(
  items: [
    AdminContentItem(
      id: 'content-1',
      title: '兴国油菜花',
      slug: 'xingguo-flowers',
      type: ContentType.image,
      status: ContentStatus.published,
      summary: '过年期间在家去拍的油菜花',
      bodyMarkdown: '',
      pinned: false,
      coverMediaId: '',
      coverUrl: '',
      mediaCount: 3,
      mediaUrls: [],
      likeCount: 0,
      viewCount: 12,
      commentCount: 1,
      publishedAt: _contentDate,
      tags: [],
    ),
    AdminContentItem(
      id: 'content-2',
      title: 'Linux 常用指令',
      slug: 'linux-commands',
      type: ContentType.markdown,
      status: ContentStatus.published,
      summary: '记录我常用的命令',
      bodyMarkdown: '',
      pinned: false,
      coverMediaId: '',
      coverUrl: '',
      mediaCount: 0,
      mediaUrls: [],
      likeCount: 2,
      viewCount: 36,
      commentCount: 0,
      publishedAt: _contentDate,
      tags: [],
    ),
  ],
  page: 0,
  size: 20,
  total: 2,
);

final _commentPage = PageResult<AdminCommentItem>(
  items: [
    AdminCommentItem(
      id: 'comment-1',
      contentId: 'content-1',
      contentTitle: '置顶：我的博客启动计划',
      userId: 'user-1',
      userNickname: '沐凉',
      userEmail: 'author@example.com',
      status: AdminCommentStatus.deleted,
      body: '测试评论一',
      createdAt: _commentDate,
      updatedAt: _commentDate,
    ),
    AdminCommentItem(
      id: 'comment-2',
      contentId: 'content-2',
      contentTitle: '一组生活照片',
      userId: 'user-2',
      userNickname: '访客',
      userEmail: 'guest@example.com',
      status: AdminCommentStatus.visible,
      body: '测试评论二',
      createdAt: _commentDate,
      updatedAt: _commentDate,
    ),
  ],
  page: 0,
  size: 50,
  total: 2,
);

final _moderationCommentPage = PageResult<AdminCommentItem>(
  items: [
    AdminCommentItem(
      id: 'comment-pending',
      contentId: 'content-1',
      contentTitle: '待审核内容',
      userId: 'user-1',
      userNickname: '沐凉',
      userEmail: 'author@example.com',
      status: AdminCommentStatus.pending,
      body: '等待管理员处理',
      createdAt: _commentDate,
      updatedAt: _commentDate,
    ),
    AdminCommentItem(
      id: 'comment-blocked',
      contentId: 'content-2',
      contentTitle: '已屏蔽内容',
      userId: 'user-2',
      userNickname: '访客',
      userEmail: 'guest@example.com',
      status: AdminCommentStatus.blocked,
      body: '已被屏蔽',
      createdAt: _commentDate,
      updatedAt: _commentDate,
    ),
  ],
  page: 0,
  size: 50,
  total: 2,
);

final _contentDate = DateTime.utc(2026, 2, 22, 8, 56);
final _commentDate = DateTime.utc(2026, 6, 26, 3, 27);

Future<void> _configureView(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpContentTab(WidgetTester tester, Size size) async {
  await _configureView(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        adminContentsProvider.overrideWith((ref) async => _contentPage),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const Scaffold(body: AdminContentTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCommentTab(
  WidgetTester tester,
  Size size, {
  PageResult<AdminCommentItem>? page,
}) async {
  await _configureView(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        adminCommentsProvider.overrideWith(
          (ref, query) async => page ?? _commentPage,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const Scaffold(body: AdminCommentTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAdminContentShell(WidgetTester tester, Size size) async {
  await _configureView(tester, size);
  const admin = UserProfile(
    id: 'admin-1',
    email: 'admin@example.com',
    nickname: '管理员',
    role: 'ADMIN',
  );
  SharedPreferences.setMockInitialValues({
    'auth.user': jsonEncode(admin.toJson()),
  });

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        adminContentsProvider.overrideWith((ref) async => _contentPage),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const Scaffold(body: AdminPage(initialTab: AdminTabId.content)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('admin shell keeps page title as the primary heading', (
    tester,
  ) async {
    await _pumpAdminContentShell(tester, const Size(1000, 900));

    expect(find.byType(AdminShellHeader), findsOneWidget);
    expect(
      tester.getSize(find.byType(AdminShellHeader)).height,
      kAdminDenseControlHeight + 24,
    );
    expect(find.text('管理后台'), findsOneWidget);
    expect(find.text('内容管理'), findsNothing);
    expect(find.textContaining('当前模块'), findsNothing);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(AdminPage),
      matchesGoldenFile('goldens/admin_content_shell_1000.png'),
    );
  });

  testWidgets('content filters use a single responsive filter bar', (
    tester,
  ) async {
    await _pumpContentTab(tester, const Size(1000, 900));

    expect(find.byType(AdminFilterBar), findsOneWidget);
    expect(find.text('包含已删除'), findsOneWidget);
    expect(find.text('重置'), findsNothing);
    expect(find.text('筛选'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('包含已删除'));
    await tester.pumpAndSettle();
    expect(find.text('重置'), findsOneWidget);

    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();
    expect(find.text('重置'), findsNothing);

    await expectLater(
      find.byType(AdminContentTab),
      matchesGoldenFile('goldens/admin_content_management_1000.png'),
    );
  });

  testWidgets('comment rows and filters expose valid moderation semantics', (
    tester,
  ) async {
    await _pumpCommentTab(tester, const Size(1000, 900));

    expect(find.byType(AdminFilterBar), findsOneWidget);
    expect(find.text('评论管理'), findsNothing);
    expect(find.text('筛选'), findsNothing);

    await tester.tap(find.text('状态 · 全部'));
    await tester.pumpAndSettle();
    expect(find.text('状态 · 待审核'), findsOneWidget);
    expect(find.text('状态 · 已屏蔽'), findsOneWidget);
    await tester.tap(find.text('状态 · 全部').last);
    await tester.pumpAndSettle();

    final restoreFinder = find.ancestor(
      of: find.text('恢复'),
      matching: find.bySubtype<FilledButton>(),
    );
    final deleteFinder = find.ancestor(
      of: find.text('删除'),
      matching: find.bySubtype<TextButton>(),
    );
    final blockFinder = find.ancestor(
      of: find.text('屏蔽'),
      matching: find.bySubtype<TextButton>(),
    );
    expect(restoreFinder, findsOneWidget);
    expect(deleteFinder, findsOneWidget);
    expect(blockFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(restoreFinder).onPressed, isNotNull);
    expect(tester.widget<TextButton>(deleteFinder).onPressed, isNotNull);
    expect(tester.widget<TextButton>(blockFinder).onPressed, isNotNull);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(AdminCommentTab),
      matchesGoldenFile('goldens/admin_comment_management_1000.png'),
    );
  });

  testWidgets('pending and blocked comments expose moderation actions', (
    tester,
  ) async {
    await _pumpCommentTab(
      tester,
      const Size(1000, 900),
      page: _moderationCommentPage,
    );

    expect(find.text('待审核'), findsOneWidget);
    expect(find.text('已屏蔽'), findsOneWidget);
    expect(find.text('通过'), findsNWidgets(2));
    expect(find.text('屏蔽'), findsOneWidget);
    expect(find.text('删除'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('management filters do not overflow at narrow widths', (
    tester,
  ) async {
    await _pumpCommentTab(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);

    await _pumpContentTab(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
  });
}
