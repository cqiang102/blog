import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/auth/auth_controller.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/features/admin/admin_mutation.dart';
import 'package:personal_blog_web/src/state/state.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this.validToken) : super(createBlogApiClient());

  final String? validToken;

  @override
  Future<String?> getValidAccessToken() async => validToken;
}

Widget _harness({
  required AuthController auth,
  required AdminMutationRequest request,
  required VoidCallback invalidate,
  String mutationKey = 'content:content-1',
}) {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWithValue(auth)],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, child) => FilledButton(
            onPressed: () => runAdminMutation(
              context: context,
              ref: ref,
              mutationKey: mutationKey,
              request: request,
              invalidate: invalidate,
              successMessage: '操作成功',
            ),
            child: const Text('执行'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'refreshes the session before executing and invalidates on success',
    (tester) async {
      final auth = _TestAuthController('fresh-token');
      addTearDown(auth.dispose);
      var receivedToken = '';
      var invalidationCount = 0;

      await tester.pumpWidget(
        _harness(
          auth: auth,
          request: (api, token) async => receivedToken = token,
          invalidate: () => invalidationCount += 1,
        ),
      );
      await tester.tap(find.text('执行'));
      await tester.pumpAndSettle();

      expect(receivedToken, 'fresh-token');
      expect(invalidationCount, 1);
      expect(find.text('操作成功'), findsOneWidget);
    },
  );

  testWidgets(
    'does not request or invalidate when the session is unavailable',
    (tester) async {
      final auth = _TestAuthController(null);
      addTearDown(auth.dispose);
      var requested = false;
      var invalidated = false;

      await tester.pumpWidget(
        _harness(
          auth: auth,
          request: (api, token) async => requested = true,
          invalidate: () => invalidated = true,
        ),
      );
      await tester.tap(find.text('执行'));
      await tester.pumpAndSettle();

      expect(requested, isFalse);
      expect(invalidated, isFalse);
      expect(find.text('登录状态已失效'), findsOneWidget);
    },
  );

  testWidgets('shows the API message and skips invalidation on failure', (
    tester,
  ) async {
    final auth = _TestAuthController('fresh-token');
    addTearDown(auth.dispose);
    var invalidated = false;

    await tester.pumpWidget(
      _harness(
        auth: auth,
        request: (api, token) async => throw const ApiException('服务端拒绝了操作'),
        invalidate: () => invalidated = true,
      ),
    );
    await tester.tap(find.text('执行'));
    await tester.pumpAndSettle();

    expect(invalidated, isFalse);
    expect(find.text('服务端拒绝了操作'), findsOneWidget);
    expect(find.text('操作成功'), findsNothing);
  });

  testWidgets('does not expose implementation details for unexpected errors', (
    tester,
  ) async {
    final auth = _TestAuthController('fresh-token');
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      _harness(
        auth: auth,
        request: (api, token) async => throw StateError('internal detail'),
        invalidate: () {},
      ),
    );
    await tester.tap(find.text('执行'));
    await tester.pumpAndSettle();

    expect(find.text('操作失败，请稍后重试'), findsOneWidget);
    expect(find.textContaining('internal detail'), findsNothing);
  });

  testWidgets('prevents duplicate in-flight requests for the same resource', (
    tester,
  ) async {
    final auth = _TestAuthController('fresh-token');
    addTearDown(auth.dispose);
    final completion = Completer<void>();
    var requestCount = 0;
    var invalidationCount = 0;

    await tester.pumpWidget(
      _harness(
        auth: auth,
        request: (api, token) {
          requestCount += 1;
          return completion.future;
        },
        invalidate: () => invalidationCount += 1,
      ),
    );

    await tester.tap(find.text('执行'));
    await tester.pump();
    await tester.tap(find.text('执行'));
    await tester.pump();

    expect(requestCount, 1);
    expect(invalidationCount, 0);

    completion.complete();
    await tester.pumpAndSettle();

    expect(requestCount, 1);
    expect(invalidationCount, 1);
  });

  testWidgets('allows different resources to mutate concurrently', (
    tester,
  ) async {
    final auth = _TestAuthController('fresh-token');
    addTearDown(auth.dispose);
    final completions = {
      'content:1': Completer<void>(),
      'content:2': Completer<void>(),
    };
    final requestCounts = <String, int>{};

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWithValue(auth)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) => Row(
                children: [
                  for (final key in completions.keys)
                    FilledButton(
                      onPressed: () => runAdminMutation(
                        context: context,
                        ref: ref,
                        mutationKey: key,
                        request: (api, token) {
                          requestCounts.update(
                            key,
                            (count) => count + 1,
                            ifAbsent: () => 1,
                          );
                          return completions[key]!.future;
                        },
                        invalidate: () {},
                        successMessage: '操作成功',
                      ),
                      child: Text(key),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('content:1'));
    await tester.tap(find.text('content:2'));
    await tester.pump();
    await tester.tap(find.text('content:1'));
    await tester.pump();

    expect(requestCounts, {'content:1': 1, 'content:2': 1});

    for (final completion in completions.values) {
      completion.complete();
    }
    await tester.pumpAndSettle();
  });
}
