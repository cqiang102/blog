import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/api/api_client_base.dart';
import 'package:personal_blog_web/src/core/api/api_exception.dart';

void main() {
  test(
    'normalizes an HTTP error returned by the refreshed-token retry',
    () async {
      final dio = Dio();
      var attempts = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            attempts += 1;
            final statusCode = attempts == 1 ? 401 : 500;
            final message = attempts == 1 ? '令牌已过期' : '服务暂时不可用';
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Object?>(
                  requestOptions: options,
                  statusCode: statusCode,
                  data: {'success': false, 'message': message},
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      final client = ApiClientBase(dio: dio);
      client.onUnauthorized = () async => 'new-token';

      await expectLater(
        client.get('contents', accessToken: 'old-token'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 500)
              .having((error) => error.message, 'message', '服务暂时不可用'),
        ),
      );
      expect(attempts, 2);
    },
  );
}
