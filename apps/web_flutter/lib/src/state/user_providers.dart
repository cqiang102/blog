// 用户相关 Provider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import 'ai_chat_state.dart';
import 'api_providers.dart';

/// 用户活动记录 Provider
final userActivityProvider =
    FutureProvider.autoDispose.family<PageResult<UserActivity>, String>((ref, type) {
      final token = ref.watch(authControllerProvider).accessToken;
      if (token == null) {
        throw const ApiException('请先登录');
      }
      return ref
          .watch(apiClientProvider)
          .fetchMyActivity(accessToken: token, type: type);
    });

/// AI 配额 Provider
final aiQuotaProvider = FutureProvider<AiQuota>((ref) {
  final token = ref.watch(authControllerProvider).accessToken;
  if (token == null) {
    throw const ApiException('请先登录');
  }
  return ref.watch(apiClientProvider).fetchAiQuota(token);
});

/// AI 聊天状态 Provider
final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier();
});
