import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/core/models.dart';

BlogApiClient _clientReturning(Object? payload) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true, 'data': payload},
        ),
      ),
    ),
  );
  return BlogApiClient(dio: dio, baseUrl: 'http://decode.test/api/v1');
}

void main() {
  test('public paged endpoints reject malformed items', () async {
    final client = _clientReturning({
      'items': [
        {'id': 'valid'},
        'not-an-object',
      ],
      'page': 0,
      'size': 10,
      'total': 2,
    });

    await expectLater(
      client.fetchContents(const ContentListQuery()),
      throwsA(isA<ApiException>()),
    );
  });

  test('public object-list endpoints reject malformed items', () async {
    final malformedList = [<String, Object?>{}, 'not-an-object'];

    await expectLater(
      _clientReturning(malformedList).fetchTags(),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      _clientReturning(malformedList).fetchFriends(),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      _clientReturning(malformedList).fetchAiSessions('token'),
      throwsA(isA<ApiException>()),
    );
  });

  test('public object endpoints normalize malformed payloads', () async {
    await expectLater(
      _clientReturning('not-an-object').fetchProfile('token'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          '后端响应数据格式不正确',
        ),
      ),
    );
  });

  test(
    'nested object lists reject malformed items instead of dropping them',
    () async {
      final client = _clientReturning({
        'pinned': [
          {'id': 'valid'},
          'not-an-object',
        ],
        'latest': const [],
        'mostLiked': const [],
      });

      await expectLater(
        client.fetchRecommendations(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            '后端响应数据格式不正确',
          ),
        ),
      );
    },
  );
}
