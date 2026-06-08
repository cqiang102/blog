// 通用 UI 扩展
// 提供共享的错误处理和上下文工具方法

import 'package:flutter/material.dart';

import 'api_client.dart';

/// BuildContext 扩展，提供通用的 SnackBar 提示方法
extension SnackbarContextX on BuildContext {
  /// 显示错误 SnackBar
  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 显示成功 SnackBar
  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// 通用的异步操作错误处理包装器
/// 统一处理 ApiException 和其他异常
Future<T?> runWithErrorHandling<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? successMessage,
  void Function(String error)? onError,
}) async {
  try {
    final result = await action();
    if (successMessage != null && context.mounted) {
      context.showSuccess(successMessage);
    }
    return result;
  } on ApiException catch (error) {
    if (onError != null) {
      onError(error.message);
    } else if (context.mounted) {
      context.showError(error.message);
    }
    return null;
  } catch (error) {
    final message = error.toString();
    if (onError != null) {
      onError(message);
    } else if (context.mounted) {
      context.showError(message);
    }
    return null;
  }
}
