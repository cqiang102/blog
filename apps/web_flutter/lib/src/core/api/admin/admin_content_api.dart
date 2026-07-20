import 'package:dio/dio.dart';

import '../../models.dart';
import '../api_client_base.dart';

/// 管理后台 AdminContentApi 接口。
mixin AdminContentApi on ApiClientBase {
  /// 获取媒体编辑器使用的轻量内容选项，支持远程搜索和分页。
  Future<PageResult<AdminContentOption>> fetchAdminContentOptions({
    required String accessToken,
    required AdminContentOptionsQuery query,
    CancelToken? cancelToken,
  }) async {
    final data = await get(
      '/admin/contents/options',
      accessToken: accessToken,
      cancelToken: cancelToken,
      queryParameters: {
        'query': query.query.trim(),
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return pageResult(data, AdminContentOption.fromJson);
  }

  /// 获取管理后台内容列表
  Future<PageResult<AdminContentItem>> fetchAdminContents({
    required String accessToken,
    required AdminContentQuery query,
  }) async {
    final data = await get(
      '/admin/contents',
      accessToken: accessToken,
      queryParameters: {
        'page': query.page.toString(),
        'size': query.size.toString(),
        if (query.includeDeleted) 'includeDeleted': 'true',
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.status != null) 'status': query.status!.apiValue,
        if (query.type != null) 'type': query.type!.apiValue,
      },
    );
    return pageResult(data, AdminContentItem.fromJson);
  }

  /// 获取单个管理后台内容
  Future<AdminContentItem> fetchAdminContent({
    required String accessToken,
    required String id,
  }) async {
    final data = await get('/admin/contents/$id', accessToken: accessToken);
    return decodeObject(data, AdminContentItem.fromJson);
  }

  /// 创建管理后台内容
  Future<AdminContentItem> createAdminContent({
    required String accessToken,
    required AdminContentDraft draft,
  }) async {
    final data = await post(
      '/admin/contents',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return decodeObject(data, AdminContentItem.fromJson);
  }

  /// 更新管理后台内容
  Future<AdminContentItem> updateAdminContent({
    required String accessToken,
    required String id,
    required AdminContentDraft draft,
  }) async {
    final data = await put(
      '/admin/contents/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return decodeObject(data, AdminContentItem.fromJson);
  }

  /// 归档管理后台内容（现改为逻辑删除）
  Future<void> archiveAdminContent({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/contents/$id', accessToken: accessToken);
  }

  /// 恢复已逻辑删除的内容
  Future<void> restoreAdminContent({
    required String accessToken,
    required String id,
  }) async {
    await put(
      '/admin/contents/$id/restore',
      accessToken: accessToken,
      body: {},
    );
  }
}
