// 内容筛选状态管理
// 使用 Riverpod 管理内容列表的筛选条件

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';

/// 内容筛选状态类
/// 包含内容列表的所有筛选条件
class ContentFilterState {
  const ContentFilterState({
    this.query = '',
    this.type,
    this.tag,
    this.startDate,
    this.endDate,
  });

  final String query;
  final ContentType? type;
  final String? tag;
  final DateTime? startDate;
  final DateTime? endDate;

  /// 创建副本并更新部分字段
  ContentFilterState copyWith({
    String? query,
    ContentType? type,
    String? tag,
    DateTime? startDate,
    DateTime? endDate,
    bool clearType = false,
    bool clearTag = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return ContentFilterState(
      query: query ?? this.query,
      type: clearType ? null : (type ?? this.type),
      tag: clearTag ? null : (tag ?? this.tag),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  /// 转换为查询参数
  ContentListQuery toQuery({int page = 0, int size = 20}) {
    return ContentListQuery(
      query: query,
      tag: tag,
      type: type,
      startDate: startDate,
      endDate: endDate,
      page: page,
      size: size,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ContentFilterState &&
        other.query == query &&
        other.type == type &&
        other.tag == tag &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(query, type, tag, startDate, endDate);
}

/// 内容筛选状态通知器
/// 管理内容列表的筛选条件更新
class ContentFilterNotifier extends Notifier<ContentFilterState> {
  @override
  ContentFilterState build() => const ContentFilterState();

  /// 更新搜索关键词
  void updateQuery(String query) {
    state = state.copyWith(query: query);
  }

  /// 更新内容类型筛选
  void updateType(ContentType? type) {
    if (type == null) {
      state = state.copyWith(clearType: true);
    } else {
      state = state.copyWith(type: type);
    }
  }

  /// 更新标签筛选
  void updateTag(String? tag) {
    if (tag == null) {
      state = state.copyWith(clearTag: true);
    } else {
      state = state.copyWith(tag: tag);
    }
  }

  /// 更新开始日期筛选
  void updateStartDate(DateTime? date) {
    state = state.copyWith(
      startDate: date,
      clearStartDate: date == null,
      clearEndDate: date != null && (state.endDate?.isBefore(date) ?? false),
    );
  }

  /// 更新结束日期筛选
  void updateEndDate(DateTime? date) {
    state = state.copyWith(
      endDate: date,
      clearEndDate: date == null,
      clearStartDate: date != null && (state.startDate?.isAfter(date) ?? false),
    );
  }

  /// 清除所有筛选条件
  void clearAll() {
    state = const ContentFilterState();
  }

  /// 清除日期筛选
  void clearDates() {
    state = state.copyWith(clearStartDate: true, clearEndDate: true);
  }
}
