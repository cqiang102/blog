// 管理后台 - 概览标签页
// 展示管理指标网格和管理模块入口
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_providers.dart';
import '../../../core/constants.dart';
import '../../../core/models.dart';
import '../../../core/theme.dart';
import '../admin_widgets.dart';

/// 概览标签页
class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminDashboardProvider);

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminDashboardProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminDashboardProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _MetricGrid(metrics: data.metrics),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '管理模块',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            const _ModuleGrid(),
          ],
        ),
      ),
    );
  }
}

/// 指标网格组件
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<AdminMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= kDesktopBreakpoint
            ? 6
            : constraints.maxWidth >= kTabletBreakpoint
                ? 3
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 112,
            crossAxisSpacing: AppSpacing.sm + 4,
            mainAxisSpacing: AppSpacing.sm + 4,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _MetricCard(metric: metric);
          },
        );
      },
    );
  }
}

/// 指标卡片组件
class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final AdminMetric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              metric.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 模块网格组件
class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid();

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
        final width =
            constraints.maxWidth >= kCompactBreakpoint ? 220.0 : double.infinity;

        return Wrap(
          spacing: AppSpacing.sm + 4,
          runSpacing: AppSpacing.sm + 4,
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
