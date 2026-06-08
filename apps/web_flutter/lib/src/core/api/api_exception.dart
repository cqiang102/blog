// API 异常类
// 用于封装业务错误信息

/// API 异常类
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
