import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api_client.dart';
import '../../../core/models.dart';
import '../../../state/state.dart';
import '../../../theme/app_spacing.dart';
import '../admin_widgets.dart';

part 'content_admin/content_admin_list.dart';
part 'content_admin/content_admin_table.dart';
part 'content_admin/content_admin_components.dart';

class AdminContentTab extends ConsumerStatefulWidget {
  const AdminContentTab({super.key});

  @override
  ConsumerState<AdminContentTab> createState() => _AdminContentTabState();
}

class _AdminContentTabState extends ConsumerState<AdminContentTab> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  late ContentStatus? _statusFilter;
  late ContentType? _typeFilter;
  late bool _includeDeleted;
  bool _correctingPage = false;

  @override
  void initState() {
    super.initState();
    final query = ref.read(adminContentQueryProvider);
    _searchController = TextEditingController(text: query.query);
    _statusFilter = query.status;
    _typeFilter = query.type;
    _includeDeleted = query.includeDeleted;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _applyFilters);
  }

  void _applyFilters() {
    _searchDebounce?.cancel();
    final previous = ref.read(adminContentQueryProvider);
    final next = AdminContentQuery(
      query: _searchController.text.trim(),
      status: _statusFilter,
      type: _typeFilter,
      includeDeleted: _includeDeleted,
      size: previous.size,
    );
    ref.read(adminContentQueryProvider.notifier).update(next);
    if (next == previous) {
      ref.invalidate(adminContentsProvider);
    }
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    final size = ref.read(adminContentQueryProvider).size;
    setState(() {
      _searchController.clear();
      _statusFilter = null;
      _typeFilter = null;
      _includeDeleted = false;
    });
    ref
        .read(adminContentQueryProvider.notifier)
        .update(AdminContentQuery(size: size));
  }

  void _changePage(int page) {
    final query = ref.read(adminContentQueryProvider);
    if (page < 0 || page == query.page) return;
    ref
        .read(adminContentQueryProvider.notifier)
        .update(query.copyWith(page: page));
  }

  void _changePageSize(int size) {
    final query = ref.read(adminContentQueryProvider);
    ref
        .read(adminContentQueryProvider.notifier)
        .update(query.copyWith(page: 0, size: size));
  }

  @override
  Widget build(BuildContext context) {
    final contents = ref.watch(adminContentsProvider);
    final query = ref.watch(adminContentQueryProvider);
    final page = contents.value;

    if (page == null && contents.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (page == null && contents.hasError) {
      return AdminErrorPane(
        message: contents.error.toString(),
        onRetry: () => ref.invalidate(adminContentsProvider),
      );
    }

    if (page!.items.isEmpty &&
        page.total > 0 &&
        query.page > 0 &&
        !_correctingPage) {
      _correctingPage = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _correctingPage = false;
        _changePage(query.page - 1);
      });
    }

    return Stack(
      children: [
        _ContentList(
          page: page,
          query: query,
          searchController: _searchController,
          statusFilter: _statusFilter,
          typeFilter: _typeFilter,
          includeDeleted: _includeDeleted,
          errorMessage: contents.hasError ? contents.error.toString() : null,
          onSearchChanged: _scheduleSearch,
          onStatusFilterChanged: (value) {
            setState(() => _statusFilter = value);
            _applyFilters();
          },
          onTypeFilterChanged: (value) {
            setState(() => _typeFilter = value);
            _applyFilters();
          },
          onToggleIncludeDeleted: (value) {
            setState(() => _includeDeleted = value);
            _applyFilters();
          },
          onApply: _applyFilters,
          onClear: _clearFilters,
          onRefresh: () => ref.refresh(adminContentsProvider.future),
          onPageChanged: _changePage,
          onPageSizeChanged: _changePageSize,
          onCreate: () => _navigateToEditor(context),
          onEdit: (content) =>
              _navigateToEditor(context, contentId: content.id),
          onPreview: (content) => context.go('/contents/${content.id}'),
          onDelete: (content) => _deleteContent(context, content),
          onRestore: (content) => _restoreContent(context, content),
        ),
        if (contents.isLoading)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  void _navigateToEditor(BuildContext context, {String? contentId}) {
    final path = contentId == null
        ? '/admin/contents/new'
        : '/admin/contents/$contentId/edit';
    context.go(path);
  }

  Future<void> _deleteContent(
    BuildContext context,
    AdminContentItem content,
  ) async {
    final confirmed = await adminConfirm(
      context,
      title: '删除内容',
      message: '确认删除「${content.title}」？删除后可在“显示已删除”中恢复。',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .archiveAdminContent(accessToken: token, id: content.id);
      _refreshRelatedData();
      if (context.mounted) showAdminSnack(context, '内容已删除');
    } on ApiException catch (error) {
      if (context.mounted) showAdminSnack(context, error.message);
    } catch (error) {
      if (context.mounted) showAdminSnack(context, error.toString());
    }
  }

  Future<void> _restoreContent(
    BuildContext context,
    AdminContentItem content,
  ) async {
    final confirmed = await adminConfirm(
      context,
      title: '恢复内容',
      message: '确认恢复「${content.title}」？',
      action: '恢复',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .restoreAdminContent(accessToken: token, id: content.id);
      _refreshRelatedData();
      if (context.mounted) showAdminSnack(context, '内容已恢复');
    } on ApiException catch (error) {
      if (context.mounted) showAdminSnack(context, error.message);
    } catch (error) {
      if (context.mounted) showAdminSnack(context, error.toString());
    }
  }

  void _refreshRelatedData() {
    ref.invalidate(adminContentsProvider);
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(recommendationsProvider);
  }
}
