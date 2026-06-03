// 管理后台 - 概览标签页
// 展示管理指标网格和管理模块入口
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_providers.dart';
import '../../../core/models.dart';
import '../admin_widgets.dart';

/// 概览标签页
/// 展示管理指标网格和管理模块入口
class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminDashboardProvider);

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => AdminErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminDashboardProvider),
          ),
      data:
          (data) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminDashboardProvider),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _MetricGrid(metrics: data.metrics),
                const SizedBox(height: 24),
                Text(
                  '管理模块',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const _ModuleGrid(),
              ],
            ),
          ),
    );
  }
}

/// 指标网格组件
/// 响应式展示管理指标（如内容数、用户数等）
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<AdminMetric> metrics; // 指标列表

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 1100
                ? 6
                : constraints.maxWidth >= 720
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 112,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(metric.label),
                    const SizedBox(height: 8),
                    Text(
                      metric.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 模块网格组件
/// 展示管理模块入口卡片（内容管理、标签管理等）
class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid();

  /// 管理模块列表（名称和图标）
  static const _modules = [
    ('内容管理', Icons.article_outlined),
    ('标签管理', Icons.sell_outlined),
    ('媒体管理', Icons.perm_media_outlined),
    ('评论管理', Icons.mode_comment_outlined),
    ('浏览记录', Icons.history_outlined),
    ('点赞记录', Icons.favorite_border),
    ('朋友管理', Icons.people_outline),
    ('用户管理', Icons.manage_accounts_outlined),
    ('AI 聊天记录', Icons.smart_toy_outlined),
    ('个人知识库', Icons.library_books_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 680 ? 220.0 : double.infinity;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final module in _modules)
              SizedBox(
                width: width,
                child: Card(
                  child: ListTile(
                    leading: Icon(module.$2),
                    title: Text(module.$1),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
