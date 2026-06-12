// API 客户端和认证 Provider

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/api_client.dart';
import '../auth/auth_controller.dart';

/// API 客户端 Provider
final apiClientProvider = Provider<BlogApiClient>((ref) {
  final dio = Dio();
  ref.onDispose(dio.close); // 销毁时关闭 Dio 实例
  return BlogApiClient(dio: dio);
});

/// 认证控制器 Provider
final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  final controller = AuthController(ref.watch(apiClientProvider));
  controller.load(); // 初始化时加载认证状态
  return controller;
});
