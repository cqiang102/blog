// 管理后台 - 概览标签页
// 展示管理指标网格和管理模块入口
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/state.dart';
import '../../../core/constants.dart';
import '../../../core/models.dart';
import '../../../theme/app_spacing.dart';
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
        message: adminErrorMessage(error),
        onRetry: () => ref.invalidate(adminDashboardProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminDashboardProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('数据概览', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '集中查看内容和互动数据，具体管理入口位于左侧菜单。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _MetricGrid(metrics: data.metrics),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            metric.label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
