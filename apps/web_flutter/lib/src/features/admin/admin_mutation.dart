import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../state/api_providers.dart';
import 'widgets/admin_feedback.dart';

typedef AdminMutationRequest =
    Future<void> Function(BlogApiClient api, String accessToken);

final _inFlightMutationKeys = <String>{};

/// 以统一流程执行管理端写操作。
///
/// 请求前刷新即将过期的令牌；成功后统一失效相关缓存并显示提示；接口错误
/// 直接展示服务端消息。异步间隙后仅在来源组件仍挂载时更新界面状态。
Future<bool> runAdminMutation({
  required BuildContext context,
  required WidgetRef ref,
  required String mutationKey,
  required AdminMutationRequest request,
  required VoidCallback invalidate,
  required String successMessage,
}) async {
  assert(mutationKey.isNotEmpty, 'mutationKey must not be empty');
  if (!context.mounted || !_inFlightMutationKeys.add(mutationKey)) return false;

  try {
    final auth = ref.read(authControllerProvider);
    final api = ref.read(apiClientProvider);
    final token = await auth.getValidAccessToken();
    if (!context.mounted) return false;

    if (token == null || token.trim().isEmpty) {
      showAdminSnack(context, '登录状态已失效');
      return false;
    }

    await request(api, token);

    // Invalidate caches on success regardless of mount state (ref is still valid).
    invalidate();

    if (!context.mounted) return true;
    showAdminSnack(context, successMessage);
    return true;
  } catch (error) {
    if (context.mounted) {
      showAdminSnack(context, userFacingErrorMessage(error));
    }
  } finally {
    _inFlightMutationKeys.remove(mutationKey);
  }
  return false;
}
