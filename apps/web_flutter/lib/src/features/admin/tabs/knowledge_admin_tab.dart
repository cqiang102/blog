// 管理后台 - 知识库管理标签页
// 展示知识文档列表，支持编辑和筛选
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/models.dart';
import '../../../state/state.dart';
import '../../../theme/app_spacing.dart';
import '../admin_mutation.dart';
import '../admin_widgets.dart';

part 'knowledge_admin/knowledge_editor_dialog.dart';
part 'knowledge_admin/knowledge_index_status.dart';
part 'knowledge_admin/knowledge_list.dart';

/// 知识库管理标签页
class AdminKnowledgeTab extends ConsumerStatefulWidget {
  const AdminKnowledgeTab({super.key});

  @override
  ConsumerState<AdminKnowledgeTab> createState() => AdminKnowledgeTabState();
}

class AdminKnowledgeTabState extends ConsumerState<AdminKnowledgeTab>
    with AdminPageCorrectionMixin<AdminKnowledgeTab> {
  final _queryController = TextEditingController();
  bool? _enabled;
  AdminKnowledgeDocQuery _query = const AdminKnowledgeDocQuery();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(adminKnowledgeDocsProvider(_query));
    final reindexState = ref.watch(knowledgeReindexProvider);
    final indexStatus = ref.watch(knowledgeIndexStatusProvider);

    return docs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AdminErrorPane(
        message: adminErrorMessage(error),
        onRetry: () => ref.invalidate(adminKnowledgeDocsProvider(_query)),
      ),
      data: (page) {
        correctAdminPage(
          page,
          requestedPage: _query.page,
          onChanged: _changePage,
        );
        return _KnowledgeList(
          page: page,
          query: _query,
          queryController: _queryController,
          enabled: _enabled,
          onEnabledChanged: (value) => setState(() => _enabled = value),
          onApply: _applyFilters,
          onClear: _clearFilters,
          onPageChanged: _changePage,
          onOpenEditor: (doc) => _openKnowledgeEditor(context, doc: doc),
          onDelete: (doc) => _deleteKnowledgeDoc(context, doc),
          indexStatus: indexStatus,
          reindexState: reindexState,
          onReindex: () => _reindexFailedChunks(context),
          onResetReindex: () =>
              ref.read(knowledgeReindexProvider.notifier).reset(),
        );
      },
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminKnowledgeDocQuery(
        query: _queryController.text.trim(),
        enabled: _enabled,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _queryController.clear();
      _enabled = null;
      _query = const AdminKnowledgeDocQuery();
    });
  }

  void _changePage(int page) {
    if (page < 0 || page == _query.page) return;
    setState(() => _query = _query.copyWith(page: page));
  }

  Future<void> _openKnowledgeEditor(
    BuildContext context, {
    AdminKnowledgeDocItem? doc,
  }) async {
    final draft = await showDialog<AdminKnowledgeDocDraft>(
      context: context,
      builder: (context) => KnowledgeEditorDialog(doc: doc),
    );
    if (draft == null || !context.mounted) return;

    await runAdminMutation(
      context: context,
      ref: ref,
      mutationKey: 'knowledge:${doc?.id ?? 'create'}',
      request: (api, token) async {
        if (doc == null) {
          await api.createAdminKnowledgeDoc(accessToken: token, draft: draft);
        } else {
          await api.updateAdminKnowledgeDoc(
            accessToken: token,
            id: doc.id,
            draft: draft,
          );
        }
      },
      invalidate: _refreshKnowledgeState,
      successMessage: doc == null ? '知识库文档已创建' : '知识库文档已保存',
    );
  }

  Future<void> _deleteKnowledgeDoc(
    BuildContext context,
    AdminKnowledgeDocItem doc,
  ) async {
    if (!mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '删除知识库文档',
      message: '确认删除「${doc.title}」？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    await runAdminMutation(
      context: context,
      ref: ref,
      mutationKey: 'knowledge:${doc.id}',
      request: (api, token) async {
        await api.deleteAdminKnowledgeDoc(accessToken: token, id: doc.id);
      },
      invalidate: _refreshKnowledgeState,
      successMessage: '知识库文档已删除',
    );
  }

  void _refreshKnowledgeState() {
    ref.invalidate(adminKnowledgeDocsProvider(_query));
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(knowledgeIndexStatusProvider);
  }

  Future<void> _reindexFailedChunks(BuildContext context) async {
    if (!mounted) return;
    final confirmed = await adminConfirm(
      context,
      title: '重新索引知识库',
      message: '将重新生成所有嵌入失败的向量，确认继续？',
      action: '重新索引',
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(knowledgeReindexProvider.notifier).reindex();

    if (!context.mounted) return;
    final reindexState = ref.read(knowledgeReindexProvider);
    if (reindexState.hasValue) {
      final result = reindexState.value;
      if (result != null) {
        if (result.isAllSuccess) {
          showAdminSnack(context, '重新索引完成：成功 ${result.successCount} 个');
        } else {
          showAdminSnack(
            context,
            '重新索引完成：成功 ${result.successCount} 个，失败 ${result.failCount} 个',
          );
        }
      }
    }
    _refreshKnowledgeState();
  }
}
