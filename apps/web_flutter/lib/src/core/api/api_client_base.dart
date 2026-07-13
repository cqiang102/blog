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
  }) {
    return send(
      'GET',
      path,
      queryParameters: queryParameters,
      accessToken: accessToken,
    );
  }

  /// 发送 POST 请求
  Future<Object?> post(
    String path, {
    Map<String, Object?>? body,
    String? accessToken,
  }) {
    return send('POST', path, accessToken: accessToken, body: body);
  }

  /// 发送 PUT 请求
  Future<Object?> put(
    String path, {
    required String accessToken,
    required Map<String, Object?> body,
  }) {
    return send('PUT', path, accessToken: accessToken, body: body);
  }

  /// 发送 DELETE 请求
  Future<Object?> delete(String path, {required String accessToken}) {
    return send('DELETE', path, accessToken: accessToken);
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
          headers['Authorization'] = 'Bearer $newToken';
          try {
            final retryResponse = await _dio.request<Object?>(
              normalizedPath,
              data: _requestData(formData: formData, body: body),
              queryParameters: queryParameters,
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
      // Dio 的 FormData 发送后会被 finalize，刷新令牌后的重试必须使用副本。
      return formData.clone();
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
      final envelope = (response.data as Map).cast<String, dynamic>();
      return ApiException(
        envelope['message']?.toString() ?? '请求失败',
        statusCode: response.statusCode,
      );
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

    final envelope = decoded.cast<String, dynamic>();
    final success = envelope['success'] == true;
    if (!success) {
      throw ApiException(
        envelope['message']?.toString() ?? '请求失败',
        statusCode: response.statusCode,
      );
    }

    return envelope['data'];
  }

  /// 解析分页结果
  PageResult<T> pageResult<T>(
    Object? data,
    T Function(Map<String, dynamic>) mapper,
  ) {
    final json = (data as Map).cast<String, dynamic>();
    return PageResult<T>(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => mapper(item.cast<String, dynamic>()))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 10,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
