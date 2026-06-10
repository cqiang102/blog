// 应用根组件
// 负责初始化 MaterialApp.router，配置主题和路由

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';
import 'theme_controller.dart';

/// 博客应用根 Widget
/// 使用 Riverpod 进行状态管理，集成 GoRouter 路由
class BlogApp extends ConsumerWidget {
  const BlogApp({super.key});

  /// 构建应用 UI
  /// [context] 构建上下文
  /// [ref] Riverpod 引用，用于监听 Provider
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeController = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: '沐凉·日记',
      debugShowCheckedModeBanner: false,

      // 浅色主题
      theme: buildAppTheme(),

      // 深色主题 - 支持系统暗黑模式切换
      darkTheme: buildDarkAppTheme(),

      // 默认跟随系统，也允许用户手动切换并持久化
      themeMode: themeController.mode,

      // GoRouter 路由配置
      routerConfig: ref.watch(routerProvider),
    );
  }
}
