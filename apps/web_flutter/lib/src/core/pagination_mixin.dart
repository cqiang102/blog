import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'constants.dart';
import 'models.dart';

/// 通用分页列表 Mixin
/// 提供分页加载、滚动监听、重置加载等通用逻辑
mixin PaginationMixin<T extends StatefulWidget, E> on State<T> {
  final ScrollController scrollController = ScrollController();
  final List<E> items = [];
  int currentPage = 0;
  int total = 0;
  bool isLoading = false;
  bool hasMore = true;
  String? error;

  /// 每页大小，默认 20
  int get pageSize => kDefaultPageSize;

  /// 获取分页数据的抽象方法，子类必须实现
  Future<PageResult<E>> fetchPage(int page, int size);

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    loadMore();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听回调
  /// 当滚动到底部附近 200px 时触发加载更多
  void _onScroll() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - kScrollThreshold &&
        !isLoading &&
        hasMore) {
      loadMore();
    }
  }

  /// 加载更多数据
  Future<void> loadMore() async {
    if (isLoading) return;
    if (mounted) {
      setState(() {
        isLoading = true;
        error = null;
      });
    }

    try {
      final result = await fetchPage(currentPage, pageSize);
      if (mounted) {
        setState(() {
          items.addAll(result.items);
          total = result.total;
          currentPage++;
          hasMore = items.length < total;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  /// 重置列表并重新加载
  void resetAndLoad() {
    if (mounted) {
      setState(() {
        items.clear();
        currentPage = 0;
        total = 0;
        hasMore = true;
        error = null;
      });
    }
    loadMore();
  }

  /// 构建加载状态指示器
  Widget buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  /// 构建"没有更多"提示
  Widget buildNoMoreIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Text('没有更多内容了')),
    );
  }

  /// 构建错误面板
  Widget buildErrorPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: resetAndLoad,
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建空状态面板
  Widget buildEmptyPanel(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(child: Text(message)),
    );
  }
}
