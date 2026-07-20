import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/content_editor_controller.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/content_editor_draft.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/content_editor_state.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/markdown_edit_command.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/markdown_editing_controller.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/widgets/collapsible_inspector.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/widgets/editor_main_panel.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/widgets/publish_settings_panel.dart';
import 'package:personal_blog_web/src/features/admin/content_editor/widgets/tag_selector.dart';
import 'package:personal_blog_web/src/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ContentEditorState', () {
    test('uses clear labels for the three editor modes', () {
      expect(EditorEditMode.source.label, '源码');
      expect(EditorEditMode.split.label, '实时预览');
      expect(EditorEditMode.preview.label, '纯预览');
    });

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

    test('autocompletes links, fences, and lists only in valid contexts', () {
      final link = MarkdownEditCommand.autocomplete(
        previousText: '',
        value: const TextEditingValue(
          text: '[',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      expect(link?.text, '[]()');
      expect(link?.selection.baseOffset, 1);

      final thirdBacktick = MarkdownEditCommand.autocomplete(
        previousText: '``',
        value: const TextEditingValue(
          text: '```',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(thirdBacktick, isNull);

      final fence = MarkdownEditCommand.autocomplete(
        previousText: '```dart',
        value: const TextEditingValue(
          text: '```dart\n',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      expect(fence?.text, '```dart\n\n```');
      expect(fence?.selection.baseOffset, 8);

      final taskBracket = MarkdownEditCommand.autocomplete(
        previousText: '- ',
        value: const TextEditingValue(
          text: '- [',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(taskBracket, isNull);

      final fencedBracket = MarkdownEditCommand.autocomplete(
        previousText: '```\n',
        value: const TextEditingValue(
          text: '```\n[',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(fencedBracket, isNull);

      final fencedList = MarkdownEditCommand.autocomplete(
        previousText: '```\n- item',
        value: const TextEditingValue(
          text: '```\n- item\n',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      expect(fencedList, isNull);

      final list = MarkdownEditCommand.autocomplete(
        previousText: '- item',
        value: const TextEditingValue(
          text: '- item\n',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(list?.text, '- item\n- ');
    });

    test('formatting actions toggle and line actions stay selection-safe', () {
      const plain = TextEditingValue(
        text: 'foo',
        selection: TextSelection(baseOffset: 0, extentOffset: 3),
      );
      final bold = MarkdownEditCommand.apply(plain, MarkdownEditAction.bold);
      final unbold = MarkdownEditCommand.apply(bold, MarkdownEditAction.bold);
      expect(bold.text, '**foo**');
      expect(unbold.text, 'foo');
      expect(unbold.selection.textInside(unbold.text), 'foo');

      const lines = TextEditingValue(
        text: '- first\nsecond',
        selection: TextSelection(baseOffset: 2, extentOffset: 14),
      );
      final listed = MarkdownEditCommand.apply(
        lines,
        MarkdownEditAction.unorderedList,
      );
      expect(listed.text, '- first\n- second');
      expect(listed.selection.isValid, isTrue);
      expect(listed.selection.end, lessThanOrEqualTo(listed.text.length));

      final heading = MarkdownEditCommand.apply(
        const TextEditingValue(
          text: '标题',
          selection: TextSelection.collapsed(offset: 0),
        ),
        MarkdownEditAction.heading2,
      );
      expect(heading.text, '## 标题');
      expect(
        MarkdownEditCommand.apply(heading, MarkdownEditAction.heading2).text,
        '标题',
      );
    });

    test('image and upload marker commands preserve editing intent', () {
      final image = MarkdownEditCommand.image(
        const TextEditingValue(
          text: '架构图',
          selection: TextSelection(baseOffset: 0, extentOffset: 3),
        ),
        url: '/media/diagram',
      );
      expect(image.text, '![架构图](/media/diagram)');
      expect(image.selection.textInside(image.text), '架构图');

      const marker = '<!-- image-upload-1 -->';
      const markedText = '开头$marker结尾';
      const marked = TextEditingValue(
        text: markedText,
        selection: TextSelection.collapsed(offset: 27),
      );
      final replaced = MarkdownEditCommand.replaceMarker(
        marked,
        marker: marker,
        replacement: '![图片](/media/1)',
      );
      expect(replaced.text, '开头![图片](/media/1)结尾');
      expect(replaced.selection.isValid, isTrue);
      expect(replaced.selection.end, replaced.text.length);
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

      final quick = MarkdownEditCommand.apply(
        const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        ),
        MarkdownEditAction.table4x4,
      );
      expect(quick.text, contains('| 列1 | 列2 | 列3 | 列4 |'));
      expect('| 内容 | 内容 | 内容 | 内容 |'.allMatches(quick.text), hasLength(3));
    });
  });

  testWidgets('MarkdownEditingController highlights source markdown', (
    tester,
  ) async {
    final controller = MarkdownEditingController();
    controller.value = const TextEditingValue(
      text: '# 标题\n- [ ] item\n~~删除~~\n`code`',
      selection: TextSelection.collapsed(offset: 4),
      composing: TextRange(start: 2, end: 4),
    );
    addTearDown(controller.dispose);

    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(color: Colors.black),
              withComposing: true,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(span.children, isNotNull);
    expect(span.children!.length, greaterThan(1));
    expect(_textSpanColors(span).length, greaterThan(1));
    expect(
      span.children!.whereType<TextSpan>().any(
        (child) => child.style?.decoration == TextDecoration.underline,
      ),
      isTrue,
    );
    expect(
      span.children!.whereType<TextSpan>().any(
        (child) => child.style?.decoration == TextDecoration.lineThrough,
      ),
      isTrue,
    );
  });

  test('controller keeps local save dirty until the server succeeds', () async {
    final container = ProviderContainer();
    final subscription = container.listen(
      contentEditorControllerProvider(null),
      (_, _) {},
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

  testWidgets('TagSelector shows all tags and reports selection', (
    tester,
  ) async {
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

    expect(find.text('Spring Boot'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('搜索标签'), findsNothing);

    await tester.tap(find.text('Spring Boot'));
    expect(selected, 'spring-boot');
  });

  testWidgets('CollapsibleInspector releases width toward the right', (
    tester,
  ) async {
    await _configureEditorView(tester, const Size(720, 600));
    var expanded = true;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Row(
                children: [
                  const Expanded(
                    child: ColoredBox(
                      key: ValueKey('collapsible-inspector-main'),
                      color: Colors.white,
                    ),
                  ),
                  CollapsibleInspector(
                    expanded: expanded,
                    width: 320,
                    duration: const Duration(milliseconds: 120),
                    child: const ColoredBox(
                      key: ValueKey('collapsible-inspector-child'),
                      color: Colors.grey,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final viewport = find.byKey(
      const ValueKey('content-editor-settings-viewport'),
    );
    final main = find.byKey(const ValueKey('collapsible-inspector-main'));
    final child = find.byKey(const ValueKey('collapsible-inspector-child'));
    expect(tester.getSize(viewport).width, 320);
    expect(tester.getSize(main).width, 400);
    expect(tester.getTopLeft(child).dx, 400);

    update(() => expanded = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getSize(viewport).width, inExclusiveRange(0, 320));

    await tester.pumpAndSettle();
    expect(tester.getSize(viewport).width, 0);
    expect(tester.getSize(main).width, 720);
    expect(tester.getTopLeft(child).dx, 720);
    expect(tester.takeException(), isNull);
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
    expect(markdown.onTapLink, isNotNull);
    expect(markdown.builders, contains('pre'));
    expect(decoration, isA<BoxDecoration>());
    expect(boxDecoration.color, isNotNull);
    expect(boxDecoration.border, isNotNull);
    expect(markdown.styleSheet?.codeblockPadding, isNotNull);
    expect(tokenColors.length, greaterThan(1));
    expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
    expect(find.byTooltip('粗体 (Ctrl/⌘ B)'), findsNothing);
    expect(find.byTooltip('源码模式'), findsOneWidget);
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

  testWidgets('EditorMainPanel keeps live preview compact and top aligned', (
    tester,
  ) async {
    await _configureEditorView(tester, const Size(1200, 900));
    const bodyMarkdown = '# 文章标题\n\n左右内容应从同一位置开始。';
    final controllers = _EditorPanelControllers(bodyMarkdown: bodyMarkdown);
    addTearDown(controllers.dispose);

    await tester.pumpWidget(
      _editorPanelHarness(
        width: 1120,
        controllers: controllers,
        state: _editorState(
          editMode: EditorEditMode.split,
          bodyMarkdown: bodyMarkdown,
        ),
      ),
    );
    await tester.pump();

    final sourcePane = find.byKey(const ValueKey('content-editor-source-pane'));
    final previewPane = find.byKey(
      const ValueKey('content-editor-preview-pane'),
    );
    final markdownPanel = find.byKey(
      const ValueKey('content-editor-markdown-panel'),
    );
    final preview = find.byKey(
      const ValueKey('content-editor-markdown-preview'),
    );
    final sourceEditor = find.byWidgetPredicate(
      (widget) =>
          widget is EditableText && widget.controller == controllers.body,
    );
    final sourceDecorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const ValueKey('content-editor-source-field')),
        matching: find.byType(InputDecorator),
      ),
    );

    final modeSelector = tester.widget<SegmentedButton<EditorEditMode>>(
      find.byWidgetPredicate(
        (widget) => widget is SegmentedButton<EditorEditMode>,
      ),
    );

    expect(find.text('Markdown 源码'), findsNothing);
    expect(find.text('实时预览'), findsNothing);
    expect(find.text('纯预览'), findsNothing);
    expect(
      modeSelector.segments.every((segment) => segment.label == null),
      isTrue,
    );
    expect(modeSelector.showSelectedIcon, isFalse);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('content-editor-title-field')))
          .height,
      lessThan(56),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('content-editor-summary-field')))
          .height,
      lessThan(56),
    );
    expect(find.textContaining('/180'), findsNothing);
    expect(find.textContaining('/2000'), findsNothing);
    expect(sourceDecorator.decoration.enabledBorder, InputBorder.none);
    expect(sourceDecorator.decoration.focusedBorder, InputBorder.none);
    expect(sourceDecorator.decoration.filled, isFalse);
    expect(
      tester.getSize(sourcePane).width,
      greaterThan(tester.getSize(previewPane).width),
    );
    expect(tester.getSize(markdownPanel).height, lessThan(650));
    expect(
      (tester.getTopLeft(sourceEditor).dy - tester.getTopLeft(preview).dy)
          .abs(),
      lessThanOrEqualTo(4),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('EditorMainPanel stacks live preview on narrow screens', (
    tester,
  ) async {
    await _configureEditorView(tester, const Size(390, 844));
    const bodyMarkdown = '# 移动端预览\n\n窄屏上下分栏。';
    final controllers = _EditorPanelControllers(bodyMarkdown: bodyMarkdown);
    addTearDown(controllers.dispose);

    await tester.pumpWidget(
      _editorPanelHarness(
        width: 390,
        controllers: controllers,
        state: _editorState(
          editMode: EditorEditMode.split,
          bodyMarkdown: bodyMarkdown,
        ),
      ),
    );
    await tester.pump();

    final sourceSize = tester.getSize(
      find.byKey(const ValueKey('content-editor-source-pane')),
    );
    final previewSize = tester.getSize(
      find.byKey(const ValueKey('content-editor-preview-pane')),
    );

    expect(sourceSize.width, previewSize.width);
    expect(sourceSize.height, greaterThan(previewSize.height));
    expect(find.text('Markdown 源码'), findsNothing);
    expect(find.text('实时预览'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PublishSettingsPanel keeps editor controls compact', (
    tester,
  ) async {
    await _configureEditorView(tester, const Size(360, 900));
    final slugController = TextEditingController();
    addTearDown(slugController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 320,
              child: Builder(
                builder: (context) => RepaintBoundary(
                  key: const ValueKey('content-editor-settings-golden'),
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: PublishSettingsPanel(
                      state: _editorState(
                        editMode: EditorEditMode.split,
                        bodyMarkdown: '',
                      ),
                      slugController: slugController,
                      tags: const [
                        TagItem(id: '1', name: 'Flutter', slug: 'flutter'),
                        TagItem(id: '2', name: '生活', slug: 'life'),
                        TagItem(id: '3', name: 'Docker', slug: 'docker'),
                      ],
                      onSlugChanged: (_) {},
                      onTypeChanged: (_) {},
                      onStatusChanged: (_) {},
                      onPinnedChanged: (_) {},
                      onPublishedAtPressed: () {},
                      onPublishedAtCleared: () {},
                      onTagToggled: (_) {},
                      onCoverPressed: () {},
                      onCollapse: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final statusField = find.byWidgetPredicate(
      (widget) => widget is PopupMenuButton<ContentStatus>,
    );
    final typeField = find.byWidgetPredicate(
      (widget) => widget is PopupMenuButton<ContentType>,
    );
    final slugField = find.byKey(const ValueKey('content-editor-slug-field'));
    expect(tester.getSize(statusField).height, lessThanOrEqualTo(48));
    expect(tester.getSize(typeField).height, lessThanOrEqualTo(48));
    expect(tester.getSize(slugField).height, lessThanOrEqualTo(48));
    expect(
      find.descendant(of: statusField, matching: find.byType(HugeIcon)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: typeField, matching: find.byType(HugeIcon)),
      findsOneWidget,
    );
    expect(find.text('搜索标签'), findsNothing);
    expect(find.text('在首页置顶区域优先展示'), findsNothing);
    expect(find.textContaining('/220'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('content-editor-settings-panel')),
        matching: find.byKey(
          const ValueKey('content-editor-settings-collapse'),
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byKey(const ValueKey('content-editor-settings-golden')),
      matchesGoldenFile('goldens/content_editor_settings_320.png'),
    );

    final typeFieldRect = tester.getRect(typeField);
    await tester.tap(typeField);
    await tester.pumpAndSettle();
    final typeMenuItems = find.byWidgetPredicate(
      (widget) => widget is PopupMenuItem<ContentType>,
    );
    expect(typeMenuItems, findsNWidgets(ContentType.values.length));
    final firstMenuItemRect = tester.getRect(typeMenuItems.first);
    expect(firstMenuItemRect.height, 40);
    expect(firstMenuItemRect.width, lessThanOrEqualTo(160));
    expect(firstMenuItemRect.left, greaterThanOrEqualTo(typeFieldRect.left));
    expect(firstMenuItemRect.right, lessThanOrEqualTo(typeFieldRect.right + 1));
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/content_editor_settings_menu_360.png'),
    );
  });

  testWidgets('EditorMainPanel live preview visual baseline', (tester) async {
    await _configureEditorView(tester, const Size(1200, 900));
    const bodyMarkdown = '''# 写一篇清晰的文章

在左侧撰写 Markdown，右侧会同步呈现最终效果。

## 编辑要点

- 用标题建立内容层级
- 图片与代码可以直接插入
- 发布前切换到纯预览检查全文

> 本机草稿会自动保存，不会打断写作。

```dart
final message = 'Hello, Flutter';
```''';
    final controllers = _EditorPanelControllers(bodyMarkdown: bodyMarkdown);
    controllers.title.text = 'Flutter 编辑器体验优化';
    controllers.summary.text = '让源码编辑、实时预览与发布设置各自保持清晰。';
    addTearDown(controllers.dispose);

    await tester.pumpWidget(
      _editorPanelHarness(
        width: 1120,
        goldenKey: 'content-editor-main-golden',
        controllers: controllers,
        state: _editorState(
          editMode: EditorEditMode.split,
          bodyMarkdown: bodyMarkdown,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('content-editor-main-golden')),
      matchesGoldenFile('goldens/content_editor_split_1120.png'),
    );
  });

  testWidgets('EditorMainPanel shows preview table of contents for headings', (
    tester,
  ) async {
    const bodyMarkdown = '# **第一节**\n\n正文\n\n## 第二节\n\n更多正文\n\n###### 第六节';
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
    expect(find.text('第六节'), findsWidgets);
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
  double width = 960,
  String? goldenKey,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: width,
          child: Builder(
            builder: (context) {
              final panel = EditorMainPanel(
                state: state,
                titleController: controllers.title,
                summaryController: controllers.summary,
                bodyController: controllers.body,
                bodyFocusNode: controllers.bodyFocusNode,
                onTitleChanged: (_) {},
                onSummaryChanged: (_) {},
                onBodyChanged: (_) {},
                onMarkdownAction: (_) {},
                onInsertCodeBlockLanguage: (_) {},
                onInsertImage: () {},
                onOpenTableEditor: () {},
                onEditModeChanged: (_) {},
                mediaChild: const SizedBox.shrink(),
              );
              if (goldenKey == null) return panel;
              return RepaintBoundary(
                key: ValueKey(goldenKey),
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: panel,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<void> _configureEditorView(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
