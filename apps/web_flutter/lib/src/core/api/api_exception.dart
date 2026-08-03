// API 异常类
// 用于封装业务错误信息

import 'package:dio/dio.dart';

/// API 异常类
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 将 HTTP 状态码转换为适合直接展示给用户的稳定中文文案。
String friendlyStatusMessage(int? statusCode) {
  if (statusCode == null) return '请求失败，请稍后重试';
  return switch (statusCode) {
    400 => '请求参数有误，请检查后重试',
    401 => '登录已过期，请重新登录',
    403 => '没有权限执行此操作',
    404 => '请求的内容不存在',
    409 => '操作冲突，请刷新后重试',
    429 => '操作太频繁，请稍后再试',
    >= 500 => '服务器暂时不可用，请稍后重试',
    _ => '请求失败，请稍后重试',
  };
}

/// 将任意异常转换为适合直接展示给用户的稳定文案。
String userFacingErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusCode >= 400) {
      return friendlyStatusMessage(statusCode);
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => '请求超时，请稍后重试',
      DioExceptionType.connectionError => '无法连接服务器，请检查网络后重试',
      DioExceptionType.badCertificate => '安全连接验证失败，请稍后重试',
      DioExceptionType.cancel => '请求已取消',
      _ => '网络请求失败，请稍后重试',
    };
  }
  return '操作失败，请稍后重试';
}
