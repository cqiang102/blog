import 'package:dio/dio.dart';

import 'api/api_exception.dart';

/// Provider 只重试短暂的网络或服务端故障。
///
/// Riverpod 3 默认会对所有异常重试最多 10 次。404、401 等确定性业务错误
/// 不应重试，否则页面会长时间停留在加载状态并重复请求接口。
Duration? appProviderRetry(int retryCount, Object error) {
  if (error is ApiException) {
    final statusCode = error.statusCode;
    if (statusCode == null || statusCode < 500) return null;
  }

  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusCode < 500) return null;
    if (error.type == DioExceptionType.cancel ||
        error.type == DioExceptionType.badCertificate) {
      return null;
    }
  }

  if (retryCount >= 2) return null;
  return Duration(milliseconds: 400 * (retryCount + 1));
}
