import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/content_editor_controller.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/content_editor_draft.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/content_editor_state.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/widgets/tag_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ContentEditorState', () {
    test('normalizes empty covers and ignores tag order for dirty checks', () {
      final initial = ContentEditorState.fromContent(
        _content(
          coverUrl: '',
          tags: const [
            TagItem(id: '1', name: 'Flutter', slug: 'flutter'),
            TagItem(id: '2', name: 'Dart', slug: 'dart'),
          ],
        ),
      );
      final reordered = initial.copyWith(tagSlugs: const ['dart', 'flutter']);

      expect(initial.coverUrl, isNull);
      expect(initial.sameContentAs(reordered), isTrue);
    });

    test('round-trips persistent fields without transient flags', () {
      final state = ContentEditorState(
        title: '标题',
        slug: 'article',
        type: ContentType.markdown,
        status: ContentStatus.draft,
        summary: '摘要',
        bodyMarkdown: '# 正文',
        pinned: true,
        tagSlugs: const ['flutter'],
        mediaUrls: const ['/media/1'],
        coverUrl: '/media/1',
        publishedAt: DateTime.utc(2026, 6, 14, 8, 30),
        hasUnsavedChanges: true,
        isSubmitting: true,
      );

      final restored = ContentEditorState.fromJson(state.toJson());

      expect(restored.sameContentAs(state), isTrue);
      expect(restored.hasUnsavedChanges, isFalse);
      expect(restored.isSubmitting, isFalse);
    });
  });

  group('ContentEditorDraftService', () {
    test('saves a timestamped draft and restores it', () async {
      final preferences = await SharedPreferences.getInstance();
      final service = ContentEditorDraftService(preferences);
      final state = ContentEditorState.fromContent(
        null,
      ).copyWith(title: '本机草稿', bodyMarkdown: '正文');

      expect(await service.saveDraft('content-1', state), isTrue);
      final snapshot = await service.loadDraft('content-1');

      expect(snapshot, isNotNull);
      expect(snapshot!.state.title, '本机草稿');
      expect(snapshot.state.bodyMarkdown, '正文');
      expect(
        snapshot.savedAt.difference(DateTime.now().toUtc()).abs(),
        lessThan(const Duration(seconds: 5)),
      );
    });

    test('loads legacy state-only drafts', () async {
      final preferences = await SharedPreferences.getInstance();
      final state = ContentEditorState.fromContent(null).copyWith(title: '旧草稿');
      await preferences.setString(
        'content_draft_legacy',
        jsonEncode(state.toJson()),
      );

      final snapshot = await ContentEditorDraftService(
        preferences,
      ).loadDraft('legacy');

      expect(snapshot?.state.title, '旧草稿');
    });
  });

  test('controller keeps local save dirty until the server succeeds', () async {
    final container = ProviderContainer();
    final subscription = container.listen(
      contentEditorControllerProvider(null),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });

    final controller = container.read(
      contentEditorControllerProvider(null).notifier,
    );
    controller.initialize(null);
    controller.updateTitle('待提交内容');

    expect(
      container.read(contentEditorControllerProvider(null)).hasUnsavedChanges,
      isTrue,
    );
    expect(await controller.saveLocalDraft(), isTrue);
    final saved = container.read(contentEditorControllerProvider(null));
    expect(saved.hasUnsavedChanges, isTrue);
    expect(saved.lastLocalSavedAt, isNotNull);
  });

  group('AdminContentQuery', () {
    test('defaults to a manageable page size', () {
      const query = AdminContentQuery();
      expect(query.page, 0);
      expect(query.size, 20);
    });

    test('copyWith can clear nullable filters while preserving page size', () {
      const query = AdminContentQuery(
        query: 'flutter',
        status: ContentStatus.draft,
        type: ContentType.markdown,
        page: 3,
        size: 50,
      );

      final next = query.copyWith(clearStatus: true, clearType: true, page: 0);

      expect(next.query, 'flutter');
      expect(next.status, isNull);
      expect(next.type, isNull);
      expect(next.page, 0);
      expect(next.size, 50);
    });
  });

  testWidgets('TagSelector filters tags and reports selection', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagSelector(
            tags: const [
              TagItem(id: '1', name: 'Flutter', slug: 'flutter'),
              TagItem(id: '2', name: 'Spring Boot', slug: 'spring-boot'),
            ],
            selectedSlugs: const {},
            onToggle: (slug) => selected = slug,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'spring');
    await tester.pump();

    expect(find.text('Spring Boot'), findsOneWidget);
    expect(find.text('Flutter'), findsNothing);

    await tester.tap(find.text('Spring Boot'));
    expect(selected, 'spring-boot');
  });
}

AdminContentItem _content({
  String coverUrl = '/cover.jpg',
  List<TagItem> tags = const [],
}) {
  return AdminContentItem(
    id: 'content-1',
    title: '内容',
    slug: 'content',
    type: ContentType.markdown,
    status: ContentStatus.draft,
    summary: '',
    bodyMarkdown: '',
    pinned: false,
    coverMediaId: '',
    coverUrl: coverUrl,
    mediaCount: 0,
    mediaUrls: const [],
    likeCount: 0,
    viewCount: 0,
    commentCount: 0,
    publishedAt: DateTime.utc(2026, 6, 14),
    tags: tags,
  );
}
