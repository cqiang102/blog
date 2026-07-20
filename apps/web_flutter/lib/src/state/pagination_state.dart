// 分页状态管理
// 使用 Riverpod 管理分页列表的状态

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/models.dart';

/// 分页状态类
/// 包含分页列表的所有状态信息
class PaginationState<T> {
  const PaginationState({
    this.items = const [],
    this.currentPage = 0,
    this.total = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  final List<T> items;
  final int currentPage;
  final int total;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  /// 创建副本并更新部分字段
  PaginationState<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? total,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// 分页状态通知器
/// 管理分页列表的加载、重置等操作
abstract class PaginationNotifier<T> extends Notifier<PaginationState<T>> {
  static const int _pageSize = kDefaultPageSize;
  int _requestGeneration = 0;

  @override
  PaginationState<T> build() => const PaginationState();

  /// 加载更多数据
  Future<void> loadMore() async {
    if (state.isLoading) return;

    final generation = _requestGeneration;
    final page = state.currentPage;
    final previousItems = state.items;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await fetchPage(page, _pageSize);
      if (!ref.mounted || generation != _requestGeneration) return;
      final items = [...previousItems, ...result.items];
      state = state.copyWith(
        items: items,
        currentPage: page + 1,
        total: result.total,
        hasMore: items.length < result.total,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted || generation != _requestGeneration) return;
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// 重置列表并重新加载
  Future<void> resetAndLoad() async {
    final generation = ++_requestGeneration;
    state = const PaginationState(isLoading: true);
    try {
      final result = await fetchPage(0, _pageSize);
      if (!ref.mounted || generation != _requestGeneration) return;
      state = PaginationState(
        items: result.items,
        currentPage: 1,
        total: result.total,
        hasMore: result.items.length < result.total,
        isLoading: false,
      );
    } catch (e) {
      if (!ref.mounted || generation != _requestGeneration) return;
      state = PaginationState(error: e.toString(), isLoading: false);
    }
  }

  /// 清除错误状态
  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<PageResult<T>> fetchPage(int page, int size);
}
