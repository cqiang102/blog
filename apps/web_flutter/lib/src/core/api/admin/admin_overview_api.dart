import '../../models.dart';
import '../api_client_base.dart';

/// 管理后台 AdminOverviewApi 接口。
mixin AdminOverviewApi on ApiClientBase {
  /// 获取管理后台仪表盘数据
  Future<AdminDashboard> fetchAdminDashboard(String accessToken) async {
    final data = await get('/admin/dashboard', accessToken: accessToken);
    return AdminDashboard.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取管理后台审计日志
  Future<PageResult<AuditLogItem>> fetchAdminAuditLogs({
    required String accessToken,
    required AuditLogQuery query,
  }) async {
    final data = await get(
      '/admin/logs',
      accessToken: accessToken,
      queryParameters: {
        if (query.action != null && query.action!.isNotEmpty)
          'action': query.action,
        if (query.resourceType != null && query.resourceType!.isNotEmpty)
          'resourceType': query.resourceType,
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return pageResult(data, AuditLogItem.fromJson);
  }
}
