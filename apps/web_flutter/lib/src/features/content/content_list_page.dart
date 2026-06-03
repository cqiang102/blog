// 内容列表页模块
// 支持无限滚动分页、关键词搜索、标签/类型/日期范围过滤
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';
import '../../core/models.dart';

/// 内容列表页 Widget
/// 有状态组件，管理搜索、过滤条件和分页加载逻辑
class ContentListPage extends ConsumerStatefulWidget {
  const ContentListPage({super.key});

  @override
  ConsumerState<ContentListPage> createState() => _ContentListPageState();
}

/// 内容列表页状态管理
/// 管理搜索框、滚动控制器、过滤条件和分页数据
class _ContentListPageState extends ConsumerState<ContentListPage> {
  final _searchController = TextEditingController(); // 搜索框控制器
  final _scrollController = ScrollController(); // 滚动控制器，用于无限滚动
  ContentType? _type; // 内容类型过滤条件
  String? _tag; // 标签过滤条件
  DateTime? _startDate; // 日期范围-开始日期
  DateTime? _endDate; // 日期范围-结束日期

  final List<BlogContent> _items = []; // 已加载的内容列表
  int _currentPage = 0; // 当前页码
  int _total = 0; // 总内容数
  bool _isLoading = false; // 是否正在加载中
  bool _hasMore = true; // 是否还有更多数据
  String? _error; // 错误信息

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听回调
  /// 当滚动到底部附近 200px 时触发加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  /// 加载更多内容
  /// 使用当前过滤条件和页码请求 API，追加数据到列表
  Future<void> _loadMore() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final query = ContentListQuery(
        query: _searchController.text.trim(),
        tag: _tag,
        type: _type,
        startDate: _startDate,
        endDate: _endDate,
        page: _currentPage,
        size: 20,
      );
      final result = await api.fetchContents(query);
      setState(() {
        _items.addAll(result.items);
        _total = result.total;
        _currentPage++;
        _hasMore = _items.length < _total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 重置列表并重新加载
  /// 清空当前数据，重置分页状态，从第一页开始加载
  void _resetAndLoad() {
    setState(() {
      _items.clear();
      _currentPage = 0;
      _total = 0;
      _hasMore = true;
      _error = null;
    });
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        const SliverAppBar(title: Text('全部内容')),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList.list(
            children: [
              TextField(
                controller: _searchController,
                onSubmitted: (_) => _resetAndLoad(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '搜索标题、摘要、正文',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _resetAndLoad();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('全部类型'),
                    selected: _type == null,
                    onSelected: (_) {
                      setState(() => _type = null);
                      _resetAndLoad();
                    },
                  ),
                  for (final type in ContentType.values)
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _type == type,
                      onSelected: (_) {
                        setState(() => _type = type);
                        _resetAndLoad();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTagFilters(),
              const SizedBox(height: 12),
              _buildDateFilters(),
              const SizedBox(height: 24),
              _buildContentList(),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建标签过滤器
  /// 从 API 获取标签列表，渲染为可选择的 FilterChip
  Widget _buildTagFilters() {
    final tagsAsync = ref.watch(tagsProvider);
    return tagsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (tags) {
        if (tags.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('全部标签'),
              selected: _tag == null,
              onSelected: (_) {
                setState(() => _tag = null);
                _resetAndLoad();
              },
            ),
            for (final tag in tags)
              FilterChip(
                label: Text(tag.name),
                selected: _tag == tag.slug,
                onSelected: (_) {
                  setState(() => _tag = tag.slug);
                  _resetAndLoad();
                },
              ),
          ],
        );
      },
    );
  }

  /// 构建日期范围过滤器
  /// 提供开始日期和结束日期选择器，支持清除日期筛选
  Widget _buildDateFilters() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final hasDateFilter = _startDate != null || _endDate != null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          avatar: const Icon(Icons.calendar_today, size: 18),
          label: Text(_startDate != null ? dateFormat.format(_startDate!) : '开始日期'),
          onPressed: () => _selectDate(true),
        ),
        const Text('至'),
        ActionChip(
          avatar: const Icon(Icons.calendar_today, size: 18),
          label: Text(_endDate != null ? dateFormat.format(_endDate!) : '结束日期'),
          onPressed: () => _selectDate(false),
        ),
        if (hasDateFilter)
          ActionChip(
            avatar: const Icon(Icons.clear, size: 18),
            label: const Text('清除日期'),
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
              _resetAndLoad();
            },
          ),
      ],
    );
  }

  /// 选择日期
  /// [isStart] 为 true 选择开始日期，否则选择结束日期
  /// 自动校验确保开始日期不晚于结束日期
  Future<void> _selectDate(bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = DateTime(2020);
    final lastDate = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = null;
          }
        }
      });
      _resetAndLoad();
    }
  }

  /// 构建内容列表
  /// 根据加载状态显示加载指示器、错误面板、空状态或内容卡片列表
  Widget _buildContentList() {
    if (_items.isEmpty && _isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _items.isEmpty) {
      return _ErrorPanel(
        message: _error!,
        onRetry: _resetAndLoad,
      );
    }

    if (_items.isEmpty) {
      return const _EmptyPanel();
    }

    return Column(
      children: [
        for (final item in _items) ...[
          _ContentRow(content: item),
          const SizedBox(height: 12),
        ],
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_hasMore && _items.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('没有更多内容了')),
          ),
      ],
    );
  }
}

/// 内容行组件
/// 展示单条内容的缩略图、标题、摘要、类型和标签
class _ContentRow extends StatelessWidget {
  const _ContentRow({required this.content});

  final BlogContent content; // 内容数据

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/contents/${content.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _Thumb(url: content.coverUrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(
                          label: Text(content.type.label),
                          visualDensity: VisualDensity.compact,
                        ),
                        for (final tag in content.tags)
                          Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// 缩略图组件
/// 加载网络图片，失败时显示占位图标
class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String url; // 图片 URL

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return SizedBox(
        width: 132,
        height: 92,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.article_outlined),
        ),
      );
    }
    return Image.network(
      url,
      width: 132,
      height: 92,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) => SizedBox(
            width: 132,
            height: 92,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
    );
  }
}

/// 空面板组件
/// 搜索结果为空时显示的提示
class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Center(child: Text('没有找到内容')),
    );
  }
}

/// 错误面板组件
/// 加载失败时显示错误信息和重试按钮
class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message; // 错误信息
  final VoidCallback onRetry; // 重试回调

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
