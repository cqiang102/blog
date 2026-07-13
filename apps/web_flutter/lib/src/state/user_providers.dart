// 用户相关 Provider

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import 'api_providers.dart';

/// 用户活动记录 Provider
final userActivityProvider = FutureProvider.autoDispose
    .family<PageResult<UserActivity>, String>((ref, type) {
      final token = ref.watch(authControllerProvider).accessToken;
      if (token == null) {
        throw const ApiException('请先登录');
      }
      return ref
          .watch(apiClientProvider)
          .fetchMyActivity(accessToken: token, type: type);
    });
