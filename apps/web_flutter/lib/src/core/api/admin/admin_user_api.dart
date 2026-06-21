import '../../models.dart';
import '../api_client_base.dart';

/// 管理后台 AdminUserApi 接口。
mixin AdminUserApi on ApiClientBase {
  /// 获取管理后台用户列表
  Future<PageResult<AdminUserItem>> fetchAdminUsers({
    required String accessToken,
    required AdminUserQuery query,
  }) async {
    final data = await get(
      '/admin/users',
      accessToken: accessToken,
      queryParameters: {
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.role != null) 'role': query.role!.apiValue,
        if (query.status != null) 'status': query.status!.apiValue,
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return pageResult(data, AdminUserItem.fromJson);
  }

  /// 更新管理后台用户
  Future<AdminUserItem> updateAdminUser({
    required String accessToken,
    required String id,
    required AdminUserDraft draft,
  }) async {
    final data = await put(
      '/admin/users/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminUserItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台用户
  Future<void> deleteAdminUser({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/users/$id', accessToken: accessToken);
  }
}
