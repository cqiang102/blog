import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_blog_web/src/core/api/api_exception.dart';
import 'package:personal_blog_web/src/core/provider_retry.dart';

void main() {
  group('appProviderRetry', () {
    test('does not retry deterministic API errors', () {
      expect(
        appProviderRetry(0, const ApiException('内容不存在', statusCode: 404)),
        isNull,
      );
      expect(appProviderRetry(0, const ApiException('请先登录')), isNull);
    });

    test('retries transient failures at most twice', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/contents'),
        type: DioExceptionType.connectionError,
      );

      expect(appProviderRetry(0, error), const Duration(milliseconds: 400));
      expect(appProviderRetry(1, error), const Duration(milliseconds: 800));
      expect(appProviderRetry(2, error), isNull);
    });

    test('a 404 future provider executes only once', () async {
      var attempts = 0;
      final provider = FutureProvider<int>((ref) async {
        attempts += 1;
        throw const ApiException('内容不存在', statusCode: 404);
      });
      final container = ProviderContainer(retry: appProviderRetry);
      addTearDown(container.dispose);

      await expectLater(
        container.read(provider.future),
        throwsA(isA<ApiException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(attempts, 1);
    });
  });
}
