import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/content_editor_controller.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/content_editor_draft.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/content_editor_state.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/markdown_edit_command.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/markdown_editing_controller.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/widgets/editor_main_panel.dart';
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

  group('MarkdownEditCommand', () {
    test('wraps selection and focuses generated link url', () {
      const value = TextEditingValue(
        text: 'OpenAI',
        selection: TextSelection(baseOffset: 0, extentOffset: 6),
      );

      final next = MarkdownEditCommand.link(value);

      expect(next.text, '[OpenAI](url)');
      expect(next.selection.textInside(next.text), 'url');
    });

    test('inserts fenced code block with language', () {
      const value = TextEditingValue(
        text: 'print("hi");',
        selection: TextSelection(baseOffset: 0, extentOffset: 12),
      );

      final next = MarkdownEditCommand.codeBlock(value, language: 'dart');

      expect(next.text, contains('```dart'));
      expect(next.text, contains('print("hi");'));
    });

    test('updates current fenced code block language', () {
      const value = TextEditingValue(
        text: '```bash\nls\n```',
        selection: TextSelection.collapsed(offset: 8),
      );

      final next = MarkdownEditCommand.codeBlock(value, language: 'dart');

      expect(next.text, '```dart\nls\n```');
    });

    test('autocompletes links, code fences, and list continuation', () {
      final link = MarkdownEditCommand.autocomplete(
        previousText: '',
        value: const TextEditingValue(
          text: '[',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      expect(link?.text, '[]()');
      expect(link?.selection.baseOffset, 1);

      final fence = MarkdownEditCommand.autocomplete(
        previousText: '``',
        value: const TextEditingValue(
          text: '```',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(fence?.text, '```\n\n```');
      expect(fence?.selection.baseOffset, 4);

      final list = MarkdownEditCommand.autocomplete(
        previousText: '- item',
        value: const TextEditingValue(
          text: '- item\n',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(list?.text, '- item\n- ');
    });

    test('generates custom markdown tables', () {
      final next = MarkdownEditCommand.table(
        const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        ),
        columns: 3,
        rows: 2,
      );

      expect(next.text, contains('| 列1 | 列2 | 列3 |'));
      expect(next.text, contains('| --- | --- | --- |'));
      expect('| 内容 | 内容 | 内容 |'.allMatches(next.text), hasLength(2));
    });
  });

  testWidgets('MarkdownEditingController highlights source markdown', (
    tester,
  ) async {
    final controller = MarkdownEditingController(text: '# 标题\n- item\n`code`');
    addTearDown(controller.dispose);

    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(color: Colors.black),
              withComposing: false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(span.children, isNotNull);
    expect(span.children!.length, greaterThan(1));
    expect(_textSpanColors(span).length, greaterThan(1));
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

  testWidgets('EditorMainPanel styles markdown preview code blocks', (
    tester,
  ) async {
    final controllers = _EditorPanelControllers(
      bodyMarkdown: '```dart\nfinal answer = 42;\nprint("hi");\n```',
    );
    addTearDown(controllers.dispose);

    await tester.pumpWidget(
      _editorPanelHarness(
        controllers: controllers,
        state: _editorState(
          editMode: EditorEditMode.preview,
          bodyMarkdown: controllers.body.text,
        ),
      ),
    );
    await tester.pump();

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    final decoration = markdown.styleSheet?.codeblockDecoration;
    final boxDecoration = decoration! as BoxDecoration;
    final highlightedCode = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((widget) => widget.textSpan)
        .whereType<TextSpan>()
        .singleWhere((span) => _textSpanPlainText(span).contains('answer'));
    final tokenColors = _textSpanColors(highlightedCode);

    expect(markdown.fitContent, isFalse);
    expect(markdown.softLineBreak, isTrue);
    expect(markdown.builders, contains('pre'));
    expect(decoration, isA<BoxDecoration>());
    expect(boxDecoration.color, isNotNull);
    expect(boxDecoration.border, isNotNull);
    expect(markdown.styleSheet?.codeblockPadding, isNotNull);
    expect(tokenColors.length, greaterThan(1));
    expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
  });

  testWidgets('EditorMainPanel wires split mode scroll controllers', (
    tester,
  ) async {
    final bodyMarkdown = List.generate(
      80,
      (index) => '第 $index 行内容',
    ).join('\n\n');
    final controllers = _EditorPanelControllers(bodyMarkdown: bodyMarkdown);
    addTearDown(controllers.dispose);

    await tester.pumpWidget(
      _editorPanelHarness(
        controllers: controllers,
        state: _editorState(
          editMode: EditorEditMode.split,
          bodyMarkdown: bodyMarkdown,
        ),
      ),
    );
    await tester.pump();

    final previewScrollViews = tester.widgetList<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final scrollbars = tester.widgetList<Scrollbar>(find.byType(Scrollbar));
    final previewController = previewScrollViews
        .map((scrollView) => scrollView.controller)
        .whereType<ScrollController>()
        .single;
    final scrollbarControllers = scrollbars
        .map((scrollbar) => scrollbar.controller)
        .whereType<ScrollController>()
        .toList();
    final sourceController = scrollbarControllers.singleWhere(
      (controller) => controller != previewController,
    );
    final sourceEditor = find.byWidgetPredicate(
      (widget) =>
          widget is EditableText && widget.controller == controllers.body,
    );

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.byType(Scrollbar), findsAtLeastNWidgets(2));
    expect(scrollbarControllers, hasLength(2));
    expect(
      scrollbarControllers.every((controller) => controller.hasClients),
      isTrue,
    );
    expect(
      previewScrollViews.any((scrollView) => scrollView.controller != null),
      isTrue,
    );

    await tester.fling(sourceEditor, const Offset(0, -360), 1200);
    await tester.pumpAndSettle();

    expect(previewController.offset, greaterThan(0));

    sourceController.jumpTo(0);
    previewController.jumpTo(0);
    await tester.pump();

    previewController.jumpTo(previewController.position.maxScrollExtent / 2);
    await tester.pumpAndSettle();

    expect(sourceController.offset, greaterThan(0));
  });

  testWidgets('EditorMainPanel shows preview table of contents for headings', (
    tester,
  ) async {
    const bodyMarkdown = '# 第一节\n\n正文\n\n## 第二节\n\n更多正文';
    final controllers = _EditorPanelControllers(bodyMarkdown: bodyMarkdown);
    addTearDown(controllers.dispose);

    await tester.pumpWidget(
      _editorPanelHarness(
        controllers: controllers,
        state: _editorState(
          editMode: EditorEditMode.preview,
          bodyMarkdown: bodyMarkdown,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('目录'), findsOneWidget);
    expect(find.text('第一节'), findsWidgets);
    expect(find.text('第二节'), findsWidgets);
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

ContentEditorState _editorState({
  required EditorEditMode editMode,
  required String bodyMarkdown,
}) {
  return ContentEditorState(
    title: '标题',
    slug: 'markdown-preview',
    type: ContentType.markdown,
    status: ContentStatus.draft,
    summary: '摘要',
    bodyMarkdown: bodyMarkdown,
    pinned: false,
    tagSlugs: const [],
    editMode: editMode,
  );
}

Widget _editorPanelHarness({
  required _EditorPanelControllers controllers,
  required ContentEditorState state,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 960,
          child: EditorMainPanel(
            state: state,
            titleController: controllers.title,
            summaryController: controllers.summary,
            bodyController: controllers.body,
            bodyFocusNode: controllers.bodyFocusNode,
            onTitleChanged: (_) {},
            onSummaryChanged: (_) {},
            onBodyChanged: (_) {},
            onInsertMarkdown: (_, _) {},
            onInsertCodeBlockLanguage: (_) {},
            onInsertImage: () {},
            onOpenTableEditor: () {},
            onEditModeChanged: (_) {},
            mediaChild: const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}

class _EditorPanelControllers {
  _EditorPanelControllers({required String bodyMarkdown})
    : title = TextEditingController(text: '标题'),
      summary = TextEditingController(text: '摘要'),
      body = TextEditingController(text: bodyMarkdown);

  final TextEditingController title;
  final TextEditingController summary;
  final TextEditingController body;
  final FocusNode bodyFocusNode = FocusNode();

  void dispose() {
    title.dispose();
    summary.dispose();
    body.dispose();
    bodyFocusNode.dispose();
  }
}

String _textSpanPlainText(TextSpan span) {
  final buffer = StringBuffer(span.text ?? '');
  final children = span.children;
  if (children == null) return buffer.toString();

  for (final child in children) {
    if (child is TextSpan) {
      buffer.write(_textSpanPlainText(child));
    }
  }

  return buffer.toString();
}

Set<Color> _textSpanColors(TextSpan span) {
  final colors = <Color>{};
  final color = span.style?.color;
  if (color != null) {
    colors.add(color);
  }

  final children = span.children;
  if (children == null) return colors;

  for (final child in children) {
    if (child is TextSpan) {
      colors.addAll(_textSpanColors(child));
    }
  }

  return colors;
}
