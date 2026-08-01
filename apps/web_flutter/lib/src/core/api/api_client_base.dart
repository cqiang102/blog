// API 客户端基类
// 封装 Dio 的基础 HTTP 请求方法，支持 401 自动刷新令牌

import 'dart:convert';

import 'package:dio/dio.dart';

import '../models.dart';
import 'api_exception.dart';
import 'dio_credentials.dart';

/// API 基础 URL，通过编译时常量配置
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api/v1',
);

const _apiConnectTimeout = Duration(seconds: 15);
const _apiSendTimeout = Duration(seconds: 30);
const _apiReceiveTimeout = Duration(seconds: 30);

String _normalizeBaseUrl(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;

String _normalizePath(String path) => path.startsWith('/') ? path : '/$path';

/// API 客户端基类
/// 基于 Dio 封装所有 HTTP 请求，支持 401 自动刷新令牌
class ApiClientBase {
  ApiClientBase({required Dio dio, String baseUrl = apiBaseUrl})
    : _dio = dio,
      baseUrl = _normalizeBaseUrl(baseUrl) {
    configureDioCredentials(_dio);
    _dio.options.baseUrl = this.baseUrl;
    _dio.options.headers = {'Accept': 'application/json'};
    _dio.options.connectTimeout ??= _apiConnectTimeout;
    _dio.options.sendTimeout ??= _apiSendTimeout;
    _dio.options.receiveTimeout ??= _apiReceiveTimeout;
  }

  final Dio _dio;
  Dio get dio => _dio;
  final String baseUrl;

  /// 401 时的回调，用于刷新令牌
  Future<String?> Function()? onUnauthorized;

  /// 发送 GET 请求
  Future<Object?> get(
    String path, {
    Map<String, dynamic> queryParameters = const {},
    String? accessToken,
    CancelToken? cancelToken,
  }) {
    return send(
      'GET',
      path,
      queryParameters: queryParameters,
      accessToken: accessToken,
      cancelToken: cancelToken,
    );
  }

  /// 发送 POST 请求
  Future<Object?> post(
    String path, {
    Map<String, Object?>? body,
    String? accessToken,
    CancelToken? cancelToken,
  }) {
    return send(
      'POST',
      path,
      accessToken: accessToken,
      body: body,
      cancelToken: cancelToken,
    );
  }

  /// 发送 PUT 请求
  Future<Object?> put(
    String path, {
    required String accessToken,
    required Map<String, Object?> body,
    CancelToken? cancelToken,
  }) {
    return send(
      'PUT',
      path,
      accessToken: accessToken,
      body: body,
      cancelToken: cancelToken,
    );
  }

  /// 发送 DELETE 请求
  Future<Object?> delete(
    String path, {
    required String accessToken,
    CancelToken? cancelToken,
  }) {
    return send(
      'DELETE',
      path,
      accessToken: accessToken,
      cancelToken: cancelToken,
    );
  }

  /// 发送 HTTP 请求的核心方法
  /// 支持 401 自动刷新令牌，使用 Dio 拦截器模式
  Future<Object?> send(
    String method,
    String path, {
    Map<String, dynamic> queryParameters = const {},
    String? accessToken,
    Map<String, Object?>? body,
    FormData? formData,
    CancelToken? cancelToken,
  }) async {
    final normalizedPath = _normalizePath(path);
    final headers = <String, String>{
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

    try {
      final response = await _dio.request<Object?>(
        normalizedPath,
        data: _requestData(formData: formData, body: body),
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: headers,
          // formData 时让 Dio 自动设置 multipart content type
          contentType: formData != null
              ? null
              : (body != null ? 'application/json' : null),
        ),
      );

      return extractData(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 &&
          accessToken != null &&
          onUnauthorized != null) {
        final newToken = await onUnauthorized!();
        if (newToken != null) {
          if (cancelToken?.isCancelled ?? false) {
            throw const ApiException('请求已取消');
          }
          headers['Authorization'] = 'Bearer $newToken';
          try {
            final retryResponse = await _dio.request<Object?>(
              normalizedPath,
              data: _requestData(
                formData: formData?.clone(),
                body: body,
              ),
              queryParameters: queryParameters,
              cancelToken: cancelToken,
              options: Options(
                method: method,
                headers: headers,
                contentType: formData != null
                    ? null
                    : (body != null ? 'application/json' : null),
              ),
            );
            return extractData(retryResponse);
          } on DioException catch (retryError) {
            throw _apiException(retryError);
          }
        }
      }
      throw _apiException(e);
    }
  }

  Object? _requestData({
    required FormData? formData,
    required Map<String, Object?>? body,
  }) {
    if (formData != null) {
      return formData;
    }
    return body != null ? jsonEncode(body) : null;
  }

  ApiException _apiException(DioException error) {
    final response = error.response;
    if (response == null) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => const ApiException('请求超时，请稍后重试'),
        DioExceptionType.connectionError => const ApiException(
          '无法连接服务器，请检查网络后重试',
        ),
        DioExceptionType.badCertificate => const ApiException('安全连接验证失败，请稍后重试'),
        DioExceptionType.cancel => const ApiException('请求已取消'),
        _ => const ApiException('网络请求失败，请稍后重试'),
      };
    }

    if (response.data is Map) {
      try {
        final envelope = _jsonObject(response.data);
        return ApiException(
          envelope['message']?.toString() ?? '请求失败',
          statusCode: response.statusCode,
        );
      } on ApiException {
        return ApiException('请求失败', statusCode: response.statusCode);
      }
    }
    return ApiException(
      error.message ?? '请求失败',
      statusCode: response.statusCode,
    );
  }

  /// 从 Dio 响应中提取业务数据
  Object? extractData(Response<Object?> response) {
    final decoded = response.data;
    if (decoded is! Map) {
      throw ApiException('后端响应格式不正确', statusCode: response.statusCode);
    }

    late final Map<String, dynamic> envelope;
    try {
      envelope = _jsonObject(decoded);
    } on ApiException {
      throw ApiException('后端响应格式不正确', statusCode: response.statusCode);
    }
    final success = envelope['success'] == true;
    if (!success) {
      throw ApiException(
        envelope['message']?.toString() ?? '请求失败',
        statusCode: response.statusCode,
      );
    }

    return envelope['data'];
  }

  /// 解码单个 JSON 对象，并将所有结构错误统一为 [ApiException]。
  T decodeObject<T>(
    Object? data,
    T Function(Map<String, dynamic> json) mapper,
  ) {
    try {
      return mapper(_jsonObject(data));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('后端响应数据格式不正确');
    }
  }

  /// 解码 JSON 对象数组；数组中的每一项都必须是对象。
  List<T> decodeObjectList<T>(
    Object? data,
    T Function(Map<String, dynamic> json) mapper,
  ) {
    if (data is! List) {
      throw const ApiException('后端响应数据格式不正确');
    }
    try {
      return data.map((item) => mapper(_jsonObject(item))).toList();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('后端响应数据格式不正确');
    }
  }

  /// 解析分页结果
  PageResult<T> pageResult<T>(
    Object? data,
    T Function(Map<String, dynamic>) mapper,
  ) {
    try {
      final json = _jsonObject(data);
      final items = json['items'] ?? const <Object?>[];
      return PageResult<T>(
        items: decodeObjectList(items, mapper),
        page: (json['page'] as num?)?.toInt() ?? 0,
        size: (json['size'] as num?)?.toInt() ?? 10,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('后端响应数据格式不正确');
    }
  }

  Map<String, dynamic> _jsonObject(Object? data) {
    if (data is! Map) {
      throw const ApiException('后端响应数据格式不正确');
    }
    try {
      return data.cast<String, dynamic>();
    } catch (_) {
      throw const ApiException('后端响应数据格式不正确');
    }
  }
}
