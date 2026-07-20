// 管理后台 - 审计日志标签页
// 展示管理员操作日志，支持筛选
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../state/state.dart';
import '../../../core/models.dart';
import '../../../theme/app_spacing.dart';
import '../admin_widgets.dart';

/// 审计日志管理标签页
class AdminAuditLogTab extends ConsumerStatefulWidget {
  const AdminAuditLogTab({super.key});

  @override
  ConsumerState<AdminAuditLogTab> createState() => AdminAuditLogTabState();
}

class AdminAuditLogTabState extends ConsumerState<AdminAuditLogTab>
    with AdminPageCorrectionMixin<AdminAuditLogTab> {
  String? _action;
  String? _resourceType;
  AuditLogQuery _query = const AuditLogQuery();

  static const _actions = ['CREATE', 'UPDATE', 'DELETE', 'READ'];
  static const _actionLabels = {
    'CREATE': '创建',
    'UPDATE': '更新',
    'DELETE': '删除',
    'READ': '查看',
  };
  static const _resourceTypes = [
    'CONTENT',
    'TAG',
    'MEDIA',
    'COMMENT',
    'LIKE',
    'VIEW',
    'FRIEND',
    'USER',
    'KNOWLEDGE',
    'AI_CHAT',
  ];
  static const _resourceTypeLabels = {
    'CONTENT': '内容',
    'TAG': '标签',
    'MEDIA': '媒体',
    'COMMENT': '评论',
    'LIKE': '点赞',
    'VIEW': '浏览',
    'FRIEND': '友链',
    'USER': '用户',
    'KNOWLEDGE': '知识库',
    'AI_CHAT': 'AI对话',
  };

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(adminAuditLogsProvider(_query));

    return logs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: adminErrorMessage(error),
        onRetry: () => ref.invalidate(adminAuditLogsProvider(_query)),
      ),
      data: (page) {
        correctAdminPage(
          page,
          requestedPage: _query.page,
          onChanged: _changePage,
        );
        return _AuditLogList(
          page: page,
          query: _query,
          action: _action,
          resourceType: _resourceType,
          actions: _actions,
          actionLabels: _actionLabels,
          resourceTypes: _resourceTypes,
          resourceTypeLabels: _resourceTypeLabels,
          onActionChanged: (value) => setState(() => _action = value),
          onResourceTypeChanged: (value) =>
              setState(() => _resourceType = value),
          onApply: _applyFilters,
          onClear: _clearFilters,
          onPageChanged: _changePage,
        );
      },
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AuditLogQuery(action: _action, resourceType: _resourceType);
    });
  }

  void _clearFilters() {
    setState(() {
      _action = null;
      _resourceType = null;
      _query = const AuditLogQuery();
    });
  }

  void _changePage(int page) {
    if (page < 0 || page == _query.page) return;
    setState(() => _query = _query.copyWith(page: page));
  }
}

/// 审计日志列表组件
class _AuditLogList extends StatelessWidget {
  const _AuditLogList({
    required this.page,
    required this.query,
    required this.action,
    required this.resourceType,
    required this.actions,
    required this.actionLabels,
    required this.resourceTypes,
    required this.resourceTypeLabels,
    required this.onActionChanged,
    required this.onResourceTypeChanged,
    required this.onApply,
    required this.onClear,
    required this.onPageChanged,
  });

  final PageResult<AuditLogItem> page;
  final AuditLogQuery query;
  final String? action;
  final String? resourceType;
  final List<String> actions;
  final Map<String, String> actionLabels;
  final List<String> resourceTypes;
  final Map<String, String> resourceTypeLabels;
  final ValueChanged<String?> onActionChanged;
  final ValueChanged<String?> onResourceTypeChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: page.items.length + 1 + (page.total > page.size ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm + 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context);
        }
        if (index > page.items.length) {
          return AdminPaginationBar(
            page: page.page,
            pageSize: page.size,
            total: page.total,
            onChanged: onPageChanged,
          );
        }
        final log = page.items[index - 1];
        return _AuditLogRow(log: log);
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AuditLogFilters(
          action: action,
          resourceType: resourceType,
          actions: actions,
          actionLabels: actionLabels,
          resourceTypes: resourceTypes,
          resourceTypeLabels: resourceTypeLabels,
          onActionChanged: onActionChanged,
          onResourceTypeChanged: onResourceTypeChanged,
          onApply: onApply,
          onClear: onClear,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Text(
          '共 ${page.total} 条日志',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (page.items.isEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const AdminEmptyPane(message: '暂无操作日志'),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// 审计日志筛选组件
class _AuditLogFilters extends StatelessWidget {
  const _AuditLogFilters({
    required this.action,
    required this.resourceType,
    required this.actions,
    required this.actionLabels,
    required this.resourceTypes,
    required this.resourceTypeLabels,
    required this.onActionChanged,
    required this.onResourceTypeChanged,
    required this.onApply,
    required this.onClear,
  });

  final String? action;
  final String? resourceType;
  final List<String> actions;
  final Map<String, String> actionLabels;
  final List<String> resourceTypes;
  final Map<String, String> resourceTypeLabels;
  final ValueChanged<String?> onActionChanged;
  final ValueChanged<String?> onResourceTypeChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AdminFilterBar(
      items: [
        AdminFilterItem(
          child: DropdownButtonFormField<String?>(
            key: ValueKey(action),
            initialValue: action,
            isExpanded: true,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(
              context,
              hintText: '操作类型 · 全部',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('操作类型 · 全部')),
              for (final a in actions)
                DropdownMenuItem(
                  value: a,
                  child: Text('操作类型 · ${actionLabels[a] ?? a}'),
                ),
            ],
            onChanged: onActionChanged,
          ),
        ),
        AdminFilterItem(
          child: DropdownButtonFormField<String?>(
            key: ValueKey(resourceType),
            initialValue: resourceType,
            isExpanded: true,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: adminFilterInputDecoration(
              context,
              hintText: '资源类型 · 全部',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('资源类型 · 全部')),
              for (final r in resourceTypes)
                DropdownMenuItem(
                  value: r,
                  child: Text('资源类型 · ${resourceTypeLabels[r] ?? r}'),
                ),
            ],
            onChanged: onResourceTypeChanged,
          ),
        ),
      ],
      actions: [
        AdminFilterApplyButton(onPressed: onApply),
        AdminFilterClearButton(onPressed: onClear),
      ],
    );
  }
}

/// 审计日志行组件
class _AuditLogRow extends StatelessWidget {
  const _AuditLogRow({required this.log});

  final AuditLogItem log;

  static const _actionLabels = {
    'CREATE': '创建',
    'UPDATE': '更新',
    'DELETE': '删除',
    'READ': '查看',
  };

  static const _resourceTypeLabels = {
    'CONTENT': '内容',
    'TAG': '标签',
    'MEDIA': '媒体',
    'COMMENT': '评论',
    'LIKE': '点赞',
    'VIEW': '浏览',
    'FRIEND': '友链',
    'USER': '用户',
    'KNOWLEDGE': '知识库',
    'AI_CHAT': 'AI对话',
    'INTERACTIONRECORD': '互动记录',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actionColor = switch (log.action) {
      'CREATE' => scheme.primaryContainer,
      'UPDATE' => scheme.tertiaryContainer,
      'DELETE' => scheme.errorContainer,
      _ => scheme.secondaryContainer,
    };

    final actionLabel = _actionLabels[log.action] ?? log.action;
    final resourceLabel =
        _resourceTypeLabels[log.resourceType] ?? log.resourceType;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            _buildHeader(context, actionLabel, resourceLabel, actionColor),
            const SizedBox(height: AppSpacing.sm),

            // 操作者信息
            _buildActorInfo(context, scheme),

            // 详情
            if (log.detail != null && log.detail!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildDetail(context, scheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String actionLabel,
    String resourceLabel,
    Color actionColor,
  ) {
    return Row(
      children: [
        Chip(
          label: Text(actionLabel),
          backgroundColor: actionColor,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: AppSpacing.sm),
        Chip(label: Text(resourceLabel), visualDensity: VisualDensity.compact),
        const Spacer(),
        Text(
          formatAdminDate(log.createdAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildActorInfo(BuildContext context, ColorScheme scheme) {
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedUser,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          log.actorNickname ?? '系统',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (log.resourceId != null) ...[
          const SizedBox(width: AppSpacing.md),
          HugeIcon(
            icon: HugeIcons.strokeRoundedTag01,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          SelectableText(
            log.resourceId!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildDetail(BuildContext context, ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        log.detail!,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}
