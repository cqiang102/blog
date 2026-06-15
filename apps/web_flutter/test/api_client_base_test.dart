import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/api/api_client_base.dart';
import 'package:personal_blog_web/src/core/api/api_exception.dart';

void main() {
  test(
    'replays multipart data with a fresh clone after token refresh',
    () async {
      final dio = Dio();
      var attempts = 0;
      final authorizationHeaders = <String?>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            attempts += 1;
            authorizationHeaders.add(
              options.headers['Authorization'] as String?,
            );

            final formData = options.data! as FormData;
            await formData.finalize().drain<void>();

            if (attempts == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<Object?>(
                    requestOptions: options,
                    statusCode: 401,
                    data: {'success': false, 'message': '令牌已过期'},
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
              return;
            }

            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {'uploaded': true},
                },
              ),
            );
          },
        ),
      );
      final client = ApiClientBase(dio: dio);
      client.onUnauthorized = () async => 'new-token';

      final result = await client.send(
        'POST',
        '/upload',
        accessToken: 'old-token',
        formData: FormData.fromMap({
          'file': MultipartFile.fromBytes([1, 2, 3], filename: 'avatar.png'),
        }),
      );

      expect(result, {'uploaded': true});
      expect(attempts, 2);
      expect(authorizationHeaders, ['Bearer old-token', 'Bearer new-token']);
    },
  );

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
