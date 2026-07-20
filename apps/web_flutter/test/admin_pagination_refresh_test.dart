import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/admin/admin_widgets.dart';
import 'package:personal_blog_web/src/features/admin/tabs/interaction_admin_tab.dart';
import 'package:personal_blog_web/src/state/state.dart';

void main() {
  testWidgets('shared admin pagination emits zero-based page changes', (
    tester,
  ) async {
    final selectedPages = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminPaginationBar(
            page: 1,
            pageSize: 20,
            total: 100,
            onChanged: selectedPages.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('上一页'));
    await tester.tap(find.text('3'));
    await tester.tap(find.byTooltip('下一页'));

    expect(selectedPages, [0, 2, 2]);
  });

  testWidgets('admin list requests the selected page without losing filters', (
    tester,
  ) async {
    final queries = <AdminRecordQuery>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminLikesProvider.overrideWith((ref, query) async {
            queries.add(query);
            return PageResult<AdminLikeItem>(
              items: const [],
              page: query.page,
              size: query.size,
              total: 101,
            );
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: AdminLikeTab())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'content-42');
    await tester.enterText(find.byType(TextField).last, 'user-7');
    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下一页'));
    await tester.pumpAndSettle();

    expect(queries.last.contentId, 'content-42');
    expect(queries.last.userId, 'user-7');
    expect(queries.last.page, 1);
  });

  testWidgets(
    'admin list returns to the previous page after its last row goes',
    (tester) async {
      final requestedPages = <int>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminLikesProvider.overrideWith((ref, query) async {
              requestedPages.add(query.page);
              return PageResult<AdminLikeItem>(
                items: const [],
                page: query.page,
                size: query.size,
                total: query.page == 0 ? 51 : 50,
              );
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: AdminLikeTab())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('下一页'));
      await tester.pumpAndSettle();

      expect(requestedPages, [0, 1, 0]);
    },
  );

  testWidgets('global admin refresh includes media options and index status', (
    tester,
  ) async {
    var mediaLoads = 0;
    var optionLoads = 0;
    var indexLoads = 0;
    const mediaQuery = AdminPageQuery(size: 80);
    const optionQuery = AdminContentOptionsQuery();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminMediaProvider.overrideWith((ref, query) async {
            mediaLoads += 1;
            return PageResult<AdminMediaItem>(
              items: const [],
              page: query.page,
              size: query.size,
              total: 0,
            );
          }),
          adminContentOptionsProvider.overrideWith((ref, query) async {
            optionLoads += 1;
            return PageResult<AdminContentOption>(
              items: const [],
              page: query.page,
              size: query.size,
              total: 0,
            );
          }),
          knowledgeIndexStatusProvider.overrideWith((ref) async {
            indexLoads += 1;
            return const IndexStatus(
              totalChunks: 0,
              chunksWithEmbedding: 0,
              failedChunks: 0,
            );
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) {
                ref.watch(adminMediaProvider(mediaQuery));
                ref.watch(adminContentOptionsProvider(optionQuery));
                ref.watch(knowledgeIndexStatusProvider);
                return FilledButton(
                  onPressed: () => invalidateAllAdminData(ref),
                  child: const Text('刷新'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect((mediaLoads, optionLoads, indexLoads), (1, 1, 1));

    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();

    expect((mediaLoads, optionLoads, indexLoads), (2, 2, 2));
  });
}
