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

/// 将任意异常转换为适合直接展示给用户的稳定文案。
String userFacingErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  return '操作失败，请稍后重试';
}
