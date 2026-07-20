import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/state/pagination_state.dart';

class _TestPaginationNotifier extends PaginationNotifier<String> {
  _TestPaginationNotifier(this.requests);

  final List<Completer<PageResult<String>>> requests;
  var _requestIndex = 0;

  @override
  Future<PageResult<String>> fetchPage(int page, int size) {
    return requests[_requestIndex++].future;
  }
}

void main() {
  test(
    'reset prevents an older page request from overwriting new data',
    () async {
      final older = Completer<PageResult<String>>();
      final reset = Completer<PageResult<String>>();
      final provider =
          NotifierProvider<_TestPaginationNotifier, PaginationState<String>>(
            () => _TestPaginationNotifier([older, reset]),
          );
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final notifier = container.read(provider.notifier);

      final olderRequest = notifier.loadMore();
      final resetRequest = notifier.resetAndLoad();
      reset.complete(
        const PageResult(items: ['new'], page: 0, size: 10, total: 1),
      );
      await resetRequest;

      older.complete(
        const PageResult(items: ['old'], page: 0, size: 10, total: 1),
      );
      await olderRequest;

      expect(container.read(provider).items, ['new']);
      expect(container.read(provider).isLoading, isFalse);
    },
  );

  test('the latest of two reset requests wins', () async {
    final first = Completer<PageResult<String>>();
    final second = Completer<PageResult<String>>();
    final provider =
        NotifierProvider<_TestPaginationNotifier, PaginationState<String>>(
          () => _TestPaginationNotifier([first, second]),
        );
    final container = ProviderContainer.test();
    addTearDown(container.dispose);
    final notifier = container.read(provider.notifier);

    final firstRequest = notifier.resetAndLoad();
    final secondRequest = notifier.resetAndLoad();
    second.complete(
      const PageResult(items: ['second'], page: 0, size: 10, total: 1),
    );
    await secondRequest;
    first.complete(
      const PageResult(items: ['first'], page: 0, size: 10, total: 1),
    );
    await firstRequest;

    expect(container.read(provider).items, ['second']);
  });
}
