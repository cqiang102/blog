/// Material 3 主题配置
/// 定义应用的颜色方案、组件样式等
library;

import 'package:flutter/material.dart';

/// 构建应用主题
/// 返回值：配置好的 ThemeData
ThemeData buildAppTheme() {
  const seed = Color(0xFF1F6F64); // 主色调种子
  const accent = Color(0xFFE7B10A); // 强调色
  const surface = Color(0xFFF7FAF8); // 表面色
  const ink = Color(0xFF16201D); // 文本色

  // 基于种子色生成颜色方案
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  ).copyWith(
    primary: seed, // 主色
    secondary: accent, // 次要色
    surface: surface, // 表面色
    onSurface: ink, // 表面上的文本色
  );

  return ThemeData(
    useMaterial3: true, // 启用 Material 3
    colorScheme: scheme,
    scaffoldBackgroundColor: surface, // 脚手架背景色
    appBarTheme: const AppBarTheme(
      centerTitle: false, // 标题不居中
      elevation: 0, // 无阴影
      backgroundColor: surface, // 背景色
      foregroundColor: ink, // 前景色
    ),
    cardTheme: CardThemeData(
      color: Colors.white, // 卡片背景色
      elevation: 0, // 无阴影
      margin: EdgeInsets.zero, // 无外边距
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // 圆角
        side: const BorderSide(color: Color(0xFFE0E7E3)), // 边框
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, // 填充背景
      fillColor: Colors.white, // 填充色
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), // 边框圆角
    ),
  );
}
