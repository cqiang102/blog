import '../../models.dart';
import '../api_client_base.dart';

/// 管理后台 AdminKnowledgeApi 接口。
mixin AdminKnowledgeApi on ApiClientBase {
  /// 获取管理后台知识库文档列表
  Future<PageResult<AdminKnowledgeDocItem>> fetchAdminKnowledgeDocs({
    required String accessToken,
    required AdminKnowledgeDocQuery query,
  }) async {
    final data = await get(
      '/admin/knowledge/docs',
      accessToken: accessToken,
      queryParameters: {
        if (query.query.trim().isNotEmpty) 'query': query.query.trim(),
        if (query.enabled != null) 'enabled': query.enabled.toString(),
        'page': query.page.toString(),
        'size': query.size.toString(),
      },
    );
    return pageResult(data, AdminKnowledgeDocItem.fromJson);
  }

  /// 创建管理后台知识库文档
  Future<AdminKnowledgeDocItem> createAdminKnowledgeDoc({
    required String accessToken,
    required AdminKnowledgeDocDraft draft,
  }) async {
    final data = await post(
      '/admin/knowledge/docs',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminKnowledgeDocItem.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  /// 更新管理后台知识库文档
  Future<AdminKnowledgeDocItem> updateAdminKnowledgeDoc({
    required String accessToken,
    required String id,
    required AdminKnowledgeDocDraft draft,
  }) async {
    final data = await put(
      '/admin/knowledge/docs/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminKnowledgeDocItem.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  /// 删除管理后台知识库文档
  Future<void> deleteAdminKnowledgeDoc({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/knowledge/docs/$id', accessToken: accessToken);
  }

  /// 手动触发重新索引所有嵌入失败的知识分块
  Future<ReindexResult> reindexFailedKnowledgeChunks({
    required String accessToken,
  }) async {
    final data = await post(
      '/admin/knowledge/docs/reindex-failed',
      accessToken: accessToken,
    );
    return ReindexResult.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 获取知识库索引状态
  Future<IndexStatus> fetchKnowledgeIndexStatus({
    required String accessToken,
  }) async {
    final data = await get(
      '/admin/knowledge/docs/index-status',
      accessToken: accessToken,
    );
    return IndexStatus.fromJson((data as Map).cast<String, dynamic>());
  }
}
