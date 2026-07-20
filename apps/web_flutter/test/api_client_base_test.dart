import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/api/api_client_base.dart';
import 'package:personal_blog_web/src/core/api/api_exception.dart';

void main() {
  test('joins base URL and request path without duplicate slashes', () async {
    final dio = Dio();
    final requestedUris = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestedUris.add(options.uri.toString());
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {'ok': true},
              },
            ),
          );
        },
      ),
    );
    final client = ApiClientBase(dio: dio, baseUrl: 'http://test/api/v1/');

    final result = await client.get('/contents');

    expect(result, {'ok': true});
    expect(client.baseUrl, 'http://test/api/v1');
    expect(requestedUris, ['http://test/api/v1/contents']);
  });

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

  test('normalizes connection failures into a user-facing message', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'XMLHttpRequest error',
          ),
        ),
      ),
    );
    final client = ApiClientBase(dio: dio);

    await expectLater(
      client.get('/contents'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          '无法连接服务器，请检查网络后重试',
        ),
      ),
    );
  });

  test('applies bounded default timeouts without overriding custom values', () {
    final defaultDio = Dio();
    ApiClientBase(dio: defaultDio);
    expect(defaultDio.options.connectTimeout, const Duration(seconds: 15));
    expect(defaultDio.options.sendTimeout, const Duration(seconds: 30));
    expect(defaultDio.options.receiveTimeout, const Duration(seconds: 30));

    final customDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    ApiClientBase(dio: customDio);
    expect(customDio.options.connectTimeout, const Duration(seconds: 3));
    expect(customDio.options.sendTimeout, const Duration(seconds: 4));
    expect(customDio.options.receiveTimeout, const Duration(seconds: 5));
  });

  test('decodes typed object and object-list payloads', () {
    final client = ApiClientBase(dio: Dio());
    String idOf(Map<String, dynamic> json) => json['id'] as String;

    expect(client.decodeObject({'id': 'one'}, idOf), 'one');
    expect(
      client.decodeObjectList([
        {'id': 'one'},
        {'id': 'two'},
      ], idOf),
      ['one', 'two'],
    );
  });

  test('normalizes malformed object payloads into ApiException', () {
    final client = ApiClientBase(dio: Dio());
    String idOf(Map<String, dynamic> json) => json['id'] as String;
    final malformedPayloads = <Object?>[
      'not-an-object',
      [
        {'id': 'valid'},
        'not-an-object',
      ],
      {'id': 42},
    ];

    expect(
      () => client.decodeObject(malformedPayloads[0], idOf),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          '后端响应数据格式不正确',
        ),
      ),
    );
    expect(
      () => client.decodeObjectList(malformedPayloads[1], idOf),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => client.decodeObject(malformedPayloads[2], idOf),
      throwsA(isA<ApiException>()),
    );
  });

  test('rejects malformed paged items instead of silently dropping them', () {
    final client = ApiClientBase(dio: Dio());

    expect(
      () => client.pageResult<String>({
        'items': [
          {'id': 'valid'},
          'not-an-object',
        ],
      }, (json) => json['id'] as String),
      throwsA(isA<ApiException>()),
    );
  });
}
