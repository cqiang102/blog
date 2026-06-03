// 管理后台 - 审计日志标签页
// 展示管理员操作日志，支持筛选
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_providers.dart';
import '../../../core/models.dart';
import '../admin_widgets.dart';

/// 审计日志管理标签页
/// 展示管理员操作日志，支持筛选
class AdminAuditLogTab extends ConsumerStatefulWidget {
  const AdminAuditLogTab({super.key});

  @override
  ConsumerState<AdminAuditLogTab> createState() => AdminAuditLogTabState();
}

/// 审计日志管理标签页状态管理
class AdminAuditLogTabState extends ConsumerState<AdminAuditLogTab> {
  String? _action; // 操作类型筛选
  String? _resourceType; // 资源类型筛选
  AuditLogQuery _query = const AuditLogQuery(); // 当前查询条件

  /// 可选操作类型
  static const _actions = ['CREATE', 'UPDATE', 'DELETE', 'READ'];
  /// 可选资源类型
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

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(adminAuditLogsProvider(_query));

    return logs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => AdminErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminAuditLogsProvider(_query)),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SectionToolbar(
                title: '操作日志',
                actionLabel: '刷新',
                actionIcon: Icons.refresh,
                onAction:
                    () => ref.invalidate(adminAuditLogsProvider(_query)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _action,
                      decoration: const InputDecoration(labelText: '操作类型'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('全部')),
                        for (final a in _actions)
                          DropdownMenuItem(value: a, child: Text(a)),
                      ],
                      onChanged: (value) => setState(() => _action = value),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _resourceType,
                      decoration: const InputDecoration(labelText: '资源类型'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('全部')),
                        for (final r in _resourceTypes)
                          DropdownMenuItem(value: r, child: Text(r)),
                      ],
                      onChanged:
                          (value) => setState(() => _resourceType = value),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _applyFilters,
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('筛选'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear),
                    label: const Text('清空'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '共 ${page.total} 条日志',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const AdminEmptyPane(message: '暂无操作日志')
              else
                for (final log in page.items) ...[
                  _AuditLogRow(log: log),
                  const SizedBox(height: 8),
                ],
            ],
          ),
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
}

/// 审计日志行组件
/// 展示单条日志的操作类型、资源类型、操作者和详情
class _AuditLogRow extends StatelessWidget {
  const _AuditLogRow({required this.log});

  final AuditLogItem log; // 日志数据

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actionColor = switch (log.action) {
      'CREATE' => scheme.primaryContainer,
      'UPDATE' => scheme.tertiaryContainer,
      'DELETE' => scheme.errorContainer,
      _ => scheme.secondaryContainer,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(log.action),
                  backgroundColor: actionColor,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(log.resourceType),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                Text(
                  formatAdminDate(log.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(log.actorNickname ?? '系统'),
                if (log.resourceId != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.tag, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  SelectableText(
                    log.resourceId!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            if (log.detail != null && log.detail!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  log.detail!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
