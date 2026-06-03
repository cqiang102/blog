/// 应用根组件
/// 负责初始化 MaterialApp.router，配置主题和路由
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

/// 博客应用根 Widget
/// 使用 Riverpod 进行状态管理，集成 GoRouter 路由
class BlogApp extends ConsumerWidget {
  const BlogApp({super.key});

  /// 构建应用 UI
  /// [context] 构建上下文
  /// [ref] Riverpod 引用，用于监听 Provider
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '个人博客', // 应用标题
      debugShowCheckedModeBanner: false, // 隐藏调试横幅
      theme: buildAppTheme(), // Material 3 主题配置
      routerConfig: ref.watch(routerProvider), // GoRouter 路由配置
    );
  }
}
