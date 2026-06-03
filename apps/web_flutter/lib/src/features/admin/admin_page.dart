// 管理后台模块
// 包含 12 个管理标签页：概览、内容、媒体、朋友、标签、评论、点赞、浏览、用户、AI、知识库、日志
// 支持 CRUD 操作和各种筛选条件
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';
import '../../core/models.dart';

/// 管理后台主页 Widget
/// 需要 ADMIN 角色才能访问，包含 12 个管理标签页
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider); // 获取认证状态
    final role = auth.user?.role.toUpperCase(); // 用户角色（大写）

    if (!auth.isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('管理员中心')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (role != 'ADMIN') {
      return Scaffold(
        appBar: AppBar(title: const Text('管理员中心')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('当前账号没有管理员权限'),
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 12,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('管理员中心'),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: () => _refresh(ref),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.space_dashboard_outlined), text: '概览'),
              Tab(icon: Icon(Icons.article_outlined), text: '内容'),
              Tab(icon: Icon(Icons.perm_media_outlined), text: '媒体'),
              Tab(icon: Icon(Icons.people_outline), text: '朋友'),
              Tab(icon: Icon(Icons.sell_outlined), text: '标签'),
              Tab(icon: Icon(Icons.mode_comment_outlined), text: '评论'),
              Tab(icon: Icon(Icons.favorite_border), text: '点赞'),
              Tab(icon: Icon(Icons.history_outlined), text: '浏览'),
              Tab(icon: Icon(Icons.manage_accounts_outlined), text: '用户'),
              Tab(icon: Icon(Icons.smart_toy_outlined), text: 'AI'),
              Tab(icon: Icon(Icons.library_books_outlined), text: '知识库'),
              Tab(icon: Icon(Icons.shield_outlined), text: '日志'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DashboardTab(),
            _ContentAdminTab(),
            _MediaAdminTab(),
            _FriendAdminTab(),
            _TagAdminTab(),
            _CommentAdminTab(),
            _LikeAdminTab(),
            _ViewAdminTab(),
            _UserAdminTab(),
            _AiChatAdminTab(),
            _KnowledgeAdminTab(),
            _AuditLogAdminTab(),
          ],
        ),
      ),
    );
  }

  /// 刷新所有管理数据
  /// 使所有管理相关的 Provider 失效，触发重新加载
  void _refresh(WidgetRef ref) {
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(adminMediaProvider);
    ref.invalidate(adminFriendsProvider);
    ref.invalidate(adminTagsProvider);
    ref.invalidate(adminCommentsProvider);
    ref.invalidate(adminLikesProvider);
    ref.invalidate(adminViewsProvider);
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminAiChatsProvider);
    ref.invalidate(adminKnowledgeDocsProvider);
    ref.invalidate(adminAuditLogsProvider);
  }
}

/// 概览标签页
/// 展示管理指标网格和管理模块入口
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminDashboardProvider);

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminDashboardProvider),
          ),
      data:
          (data) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminDashboardProvider),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _MetricGrid(metrics: data.metrics),
                const SizedBox(height: 24),
                Text(
                  '管理模块',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const _ModuleGrid(),
              ],
            ),
          ),
    );
  }
}

/// 指标网格组件
/// 响应式展示管理指标（如内容数、用户数等）
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<AdminMetric> metrics; // 指标列表

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 1100
                ? 6
                : constraints.maxWidth >= 720
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 112,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(metric.label),
                    const SizedBox(height: 8),
                    Text(
                      metric.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 模块网格组件
/// 展示管理模块入口卡片（内容管理、标签管理等）
class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid();

  /// 管理模块列表（名称和图标）
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
        final width = constraints.maxWidth >= 680 ? 220.0 : double.infinity;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
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

/// 内容管理标签页
/// 支持内容的新增、编辑、归档操作
class _ContentAdminTab extends ConsumerWidget {
  const _ContentAdminTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contents = ref.watch(adminContentsProvider);
    final tagsValue = ref.watch(adminTagsProvider);
    final tags = tagsValue.maybeWhen(
      data: (items) => items,
      orElse: () => const <TagItem>[],
    );
    final tagError = tagsValue.maybeWhen(
      error: (error, stackTrace) => error.toString(),
      orElse: () => null,
    );

    return contents.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminContentsProvider),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SectionToolbar(
                title: '内容管理',
                actionLabel: '新增内容',
                actionIcon: Icons.add,
                onAction: () => _openContentEditor(context, ref, tags),
              ),
              if (tagError != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: tagError),
              ],
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const _EmptyPane(message: '暂无内容')
              else
                for (final content in page.items) ...[
                  _ContentAdminRow(
                    content: content,
                    onEdit:
                        () => _openContentEditor(
                          context,
                          ref,
                          tags,
                          content: content,
                        ),
                    onArchive:
                        content.archived
                            ? null
                            : () => _archiveContent(context, ref, content),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  /// 打开内容编辑器对话框
  /// 新增时 content 为 null，编辑时传入现有内容数据
  Future<void> _openContentEditor(
    BuildContext context,
    WidgetRef ref,
    List<TagItem> tags, {
    AdminContentItem? content,
  }) async {
    final draft = await showDialog<AdminContentDraft>(
      context: context,
      builder: (context) => _ContentEditorDialog(content: content, tags: tags),
    );
    if (draft == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final api = ref.read(apiClientProvider);
      if (content == null) {
        await api.createAdminContent(accessToken: token, draft: draft);
      } else {
        await api.updateAdminContent(
          accessToken: token,
          id: content.id,
          draft: draft,
        );
      }
      ref.invalidate(adminContentsProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(recommendationsProvider);
      if (!context.mounted) return;
      _showSnack(context, content == null ? '内容已创建' : '内容已保存');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  /// 归档内容
  /// 弹出确认对话框后调用 API 归档内容
  Future<void> _archiveContent(
    BuildContext context,
    WidgetRef ref,
    AdminContentItem content,
  ) async {
    final confirmed = await _confirm(
      context,
      title: '归档内容',
      message: '确认归档「${content.title}」？',
      action: '归档',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .archiveAdminContent(accessToken: token, id: content.id);
      ref.invalidate(adminContentsProvider);
      ref.invalidate(adminDashboardProvider);
      ref.invalidate(recommendationsProvider);
      if (!context.mounted) return;
      _showSnack(context, '内容已归档');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }
}

/// 内容管理行组件
/// 展示单条内容的封面、标题、状态、标签和操作按钮
class _ContentAdminRow extends StatelessWidget {
  const _ContentAdminRow({
    required this.content,
    required this.onEdit,
    required this.onArchive,
  });

  final AdminContentItem content; // 内容数据
  final VoidCallback onEdit; // 编辑回调
  final VoidCallback? onArchive; // 归档回调（已归档时为 null）

  @override
  Widget build(BuildContext context) {
    final publishedAt = _formatDate(content.publishedAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MediaThumb(
                  url: content.coverUrl,
                  type: MediaAssetType.image,
                  size: const Size(96, 64),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => context.go('/contents/${content.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          content.summary.isEmpty
                              ? content.slug
                              : content.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '编辑',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '归档',
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusChip(status: content.status),
                Chip(label: Text(content.type.label)),
                if (content.pinned)
                  const Chip(
                    avatar: Icon(Icons.push_pin_outlined, size: 18),
                    label: Text('置顶'),
                  ),
                Chip(
                  avatar: const Icon(Icons.perm_media_outlined, size: 18),
                  label: Text('${content.mediaCount} 个媒体'),
                ),
                if (content.coverMediaId.isNotEmpty)
                  const Chip(
                    avatar: Icon(Icons.image_outlined, size: 18),
                    label: Text('有封面'),
                  ),
                for (final tag in content.tags) Chip(label: Text(tag.name)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _MetaText(
                  icon: Icons.favorite_outline,
                  text: '${content.likeCount}',
                ),
                _MetaText(
                  icon: Icons.visibility_outlined,
                  text: '${content.viewCount}',
                ),
                _MetaText(
                  icon: Icons.comment_outlined,
                  text: '${content.commentCount}',
                ),
                _MetaText(icon: Icons.schedule_outlined, text: publishedAt),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 媒体管理标签页
/// 支持媒体文件的上传、编辑、设为封面、删除操作
class _MediaAdminTab extends ConsumerWidget {
  const _MediaAdminTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(adminMediaProvider);
    final contentsValue = ref.watch(adminContentsProvider);
    final contents = contentsValue.maybeWhen(
      data: (page) => page.items,
      orElse: () => const <AdminContentItem>[],
    );
    final contentError = contentsValue.maybeWhen(
      error: (error, stackTrace) => error.toString(),
      orElse: () => null,
    );

    return media.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminMediaProvider),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SectionToolbar(
                title: '媒体管理',
                actionLabel: '上传文件',
                actionIcon: Icons.upload_file,
                onAction: () => _pickAndUpload(context, ref, contents),
                secondaryLabel: '外链媒体',
                secondaryIcon: Icons.add_link,
                onSecondaryAction:
                    () => _openMediaEditor(context, ref, contents),
              ),
              if (contentError != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: contentError),
              ],
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const _EmptyPane(message: '暂无媒体资源')
              else
                for (final item in page.items) ...[
                  _MediaAdminRow(
                    media: item,
                    onEdit:
                        () => _openMediaEditor(
                          context,
                          ref,
                          contents,
                          media: item,
                        ),
                    onSetCover:
                        item.contentId.isEmpty || item.cover
                            ? null
                            : () => _setCover(context, ref, item),
                    onDelete: () => _deleteMedia(context, ref, item),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  /// 选择文件并上传
  /// 打开文件选择器，选择文件后弹出上传对话框，提交到服务器
  Future<void> _pickAndUpload(
    BuildContext context,
    WidgetRef ref,
    List<AdminContentItem> contents,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !context.mounted) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        _showSnack(context, '没有读取到文件内容');
        return;
      }

      final draft = await showDialog<_UploadMediaDraft>(
        context: context,
        builder:
            (context) => _UploadMediaDialog(
              filename: file.name,
              inferredType: _inferMediaType(file.name),
              contents: contents,
            ),
      );
      if (draft == null || !context.mounted) return;

      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) return;

      await ref
          .read(apiClientProvider)
          .uploadAdminMedia(
            accessToken: token,
            bytes: bytes,
            filename: file.name,
            type: draft.type,
            contentId: draft.contentId,
          );
      _refreshMediaState(ref);
      if (!context.mounted) return;
      _showSnack(context, '文件已上传');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  /// 打开媒体编辑器对话框
  /// 新增时 media 为 null，编辑时传入现有媒体数据
  Future<void> _openMediaEditor(
    BuildContext context,
    WidgetRef ref,
    List<AdminContentItem> contents, {
    AdminMediaItem? media,
  }) async {
    final draft = await showDialog<AdminMediaDraft>(
      context: context,
      builder:
          (context) => _MediaEditorDialog(media: media, contents: contents),
    );
    if (draft == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final api = ref.read(apiClientProvider);
      if (media == null) {
        await api.createAdminMedia(accessToken: token, draft: draft);
      } else {
        await api.updateAdminMedia(
          accessToken: token,
          id: media.id,
          draft: draft,
        );
      }
      _refreshMediaState(ref);
      if (!context.mounted) return;
      _showSnack(context, media == null ? '媒体已创建' : '媒体已保存');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  /// 设置内容封面
  /// 将指定媒体设为关联内容的封面图
  Future<void> _setCover(
    BuildContext context,
    WidgetRef ref,
    AdminMediaItem media,
  ) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null || media.contentId.isEmpty) return;

    try {
      await ref
          .read(apiClientProvider)
          .setAdminContentCover(
            accessToken: token,
            contentId: media.contentId,
            mediaId: media.id,
          );
      _refreshMediaState(ref);
      if (!context.mounted) return;
      _showSnack(context, '封面已设置');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  /// 删除媒体
  /// 弹出确认对话框后调用 API 删除媒体文件
  Future<void> _deleteMedia(
    BuildContext context,
    WidgetRef ref,
    AdminMediaItem media,
  ) async {
    final confirmed = await _confirm(
      context,
      title: '删除媒体',
      message: '确认删除「${media.displayName}」？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminMedia(accessToken: token, id: media.id);
      _refreshMediaState(ref);
      if (!context.mounted) return;
      _showSnack(context, '媒体已删除');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  /// 刷新媒体相关状态
  /// 使媒体、内容、仪表盘和推荐 Provider 失效
  void _refreshMediaState(WidgetRef ref) {
    ref.invalidate(adminMediaProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(recommendationsProvider);
  }
}

/// 媒体管理行组件
/// 展示单条媒体的缩略图、名称、URL、类型和操作按钮
class _MediaAdminRow extends StatelessWidget {
  const _MediaAdminRow({
    required this.media,
    required this.onEdit,
    required this.onSetCover,
    required this.onDelete,
  });

  final AdminMediaItem media; // 媒体数据
  final VoidCallback onEdit; // 编辑回调
  final VoidCallback? onSetCover; // 设为封面回调
  final VoidCallback onDelete; // 删除回调

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDate(media.createdAt);
    final size = media.byteSize == 0 ? '' : _formatBytes(media.byteSize);
    final dimensions =
        media.width > 0 && media.height > 0
            ? '${media.width} x ${media.height}'
            : '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MediaThumb(
                  url: media.publicUrl,
                  type: media.type,
                  size: const Size(112, 72),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        media.publicUrl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(media.type.label)),
                          if (media.cover)
                            const Chip(
                              avatar: Icon(Icons.image_outlined, size: 18),
                              label: Text('封面'),
                            ),
                          if (media.contentTitle.isNotEmpty)
                            Chip(label: Text(media.contentTitle)),
                          if (media.contentType.isNotEmpty)
                            Chip(label: Text(media.contentType)),
                          if (size.isNotEmpty) Chip(label: Text(size)),
                          if (dimensions.isNotEmpty)
                            Chip(label: Text(dimensions)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaText(icon: Icons.schedule_outlined, text: createdAt),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
                OutlinedButton.icon(
                  onPressed: onSetCover,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('设封面'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 朋友管理标签页
/// 支持友链的新增、编辑、删除操作
class _FriendAdminTab extends ConsumerWidget {
  const _FriendAdminTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(adminFriendsProvider);

    return friends.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminFriendsProvider),
          ),
      data:
          (items) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SectionToolbar(
                title: '朋友管理',
                actionLabel: '新增朋友',
                actionIcon: Icons.add,
                onAction: () => _openFriendEditor(context, ref),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const _EmptyPane(message: '暂无朋友')
              else
                for (final friend in items) ...[
                  _FriendAdminRow(
                    friend: friend,
                    onEdit:
                        () => _openFriendEditor(context, ref, friend: friend),
                    onDelete: () => _deleteFriend(context, ref, friend),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  /// 打开友链编辑器对话框
  /// 新增时 friend 为 null，编辑时传入现有友链数据
  Future<void> _openFriendEditor(
    BuildContext context,
    WidgetRef ref, {
    FriendLink? friend,
  }) async {
    final draft = await showDialog<FriendDraft>(
      context: context,
      builder: (context) => _FriendEditorDialog(friend: friend),
    );
    if (draft == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final api = ref.read(apiClientProvider);
      if (friend == null) {
        await api.createAdminFriend(accessToken: token, draft: draft);
      } else {
        await api.updateAdminFriend(
          accessToken: token,
          id: friend.id,
          draft: draft,
        );
      }
      _refreshFriendState(ref);
      if (!context.mounted) return;
      _showSnack(context, friend == null ? '朋友已创建' : '朋友已保存');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  /// 删除友链
  /// 弹出确认对话框后调用 API 删除友链
  Future<void> _deleteFriend(
    BuildContext context,
    WidgetRef ref,
    FriendLink friend,
  ) async {
    final confirmed = await _confirm(
      context,
      title: '删除朋友',
      message: '确认删除「${friend.name}」？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminFriend(accessToken: token, id: friend.id);
      _refreshFriendState(ref);
      if (!context.mounted) return;
      _showSnack(context, '朋友已删除');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  /// 刷新友链相关状态
  void _refreshFriendState(WidgetRef ref) {
    ref.invalidate(adminFriendsProvider);
    ref.invalidate(friendsProvider);
    ref.invalidate(adminDashboardProvider);
  }
}

/// 友链管理行组件
/// 展示单条友链的头像、名称、简介、可见性和操作按钮
class _FriendAdminRow extends StatelessWidget {
  const _FriendAdminRow({
    required this.friend,
    required this.onEdit,
    required this.onDelete,
  });

  final FriendLink friend; // 友链数据
  final VoidCallback onEdit; // 编辑回调
  final VoidCallback onDelete; // 删除回调

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FriendAvatar(friend: friend),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        friend.intro.isEmpty ? friend.siteUrl : friend.intro,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        friend.siteUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: Icon(
                    friend.visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  label: Text(friend.visible ? '公开' : '隐藏'),
                ),
                Chip(label: Text('排序 ${friend.sortOrder}')),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 友链头像组件
/// 显示友链头像，无头像时显示名称首字符
class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.friend});

  final FriendLink friend; // 友链数据

  @override
  Widget build(BuildContext context) {
    final fallback = friend.name.isEmpty ? '?' : friend.name.substring(0, 1);
    if (friend.avatarUrl.isEmpty) {
      return CircleAvatar(radius: 24, child: Text(fallback));
    }
    return CircleAvatar(
      radius: 24,
      backgroundImage: NetworkImage(friend.avatarUrl),
      onBackgroundImageError: (_, _) {},
      child: null,
    );
  }
}

/// 标签管理标签页
/// 支持标签的新增、编辑、删除操作
class _TagAdminTab extends ConsumerWidget {
  const _TagAdminTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(adminTagsProvider);

    return tags.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminTagsProvider),
          ),
      data:
          (items) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SectionToolbar(
                title: '标签管理',
                actionLabel: '新增标签',
                actionIcon: Icons.add,
                onAction: () => _openTagEditor(context, ref),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const _EmptyPane(message: '暂无标签')
              else
                for (final tag in items) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.sell_outlined),
                      title: Text(tag.name),
                      subtitle: Text(
                        tag.description.isEmpty
                            ? tag.slug
                            : '${tag.slug} · ${tag.description}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: '编辑',
                            onPressed:
                                () => _openTagEditor(context, ref, tag: tag),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: '删除',
                            onPressed: () => _deleteTag(context, ref, tag),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  /// 打开标签编辑器对话框
  /// 新增时 tag 为 null，编辑时传入现有标签数据
  Future<void> _openTagEditor(
    BuildContext context,
    WidgetRef ref, {
    TagItem? tag,
  }) async {
    final draft = await showDialog<TagDraft>(
      context: context,
      builder: (context) => _TagEditorDialog(tag: tag),
    );
    if (draft == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final api = ref.read(apiClientProvider);
      if (tag == null) {
        await api.createAdminTag(accessToken: token, draft: draft);
      } else {
        await api.updateAdminTag(accessToken: token, id: tag.id, draft: draft);
      }
      ref.invalidate(adminTagsProvider);
      ref.invalidate(adminContentsProvider);
      if (!context.mounted) return;
      _showSnack(context, tag == null ? '标签已创建' : '标签已保存');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  /// 删除标签
  /// 弹出确认对话框后调用 API 删除标签
  Future<void> _deleteTag(
    BuildContext context,
    WidgetRef ref,
    TagItem tag,
  ) async {
    final confirmed = await _confirm(
      context,
      title: '删除标签',
      message: '确认删除「${tag.name}」？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminTag(accessToken: token, id: tag.id);
      ref.invalidate(adminTagsProvider);
      ref.invalidate(adminContentsProvider);
      if (!context.mounted) return;
      _showSnack(context, '标签已删除');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }
}

/// 评论管理标签页
/// 支持评论的筛选、删除、恢复操作
class _CommentAdminTab extends ConsumerStatefulWidget {
  const _CommentAdminTab();

  @override
  ConsumerState<_CommentAdminTab> createState() => _CommentAdminTabState();
}

/// 评论管理标签页状态管理
/// 管理评论筛选条件和 CRUD 操作
class _CommentAdminTabState extends ConsumerState<_CommentAdminTab> {
  final _contentIdController = TextEditingController(); // 内容 ID 筛选框
  final _userIdController = TextEditingController(); // 用户 ID 筛选框
  AdminCommentStatus? _status; // 评论状态筛选
  AdminCommentQuery _query = const AdminCommentQuery(); // 当前查询条件

  @override
  void dispose() {
    _contentIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(adminCommentsProvider(_query));

    return comments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminCommentsProvider(_query)),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SectionToolbar(
                title: '评论管理',
                actionLabel: '刷新',
                actionIcon: Icons.refresh,
                onAction: () => ref.invalidate(adminCommentsProvider(_query)),
              ),
              const SizedBox(height: 12),
              _CommentFilters(
                status: _status,
                contentIdController: _contentIdController,
                userIdController: _userIdController,
                onStatusChanged: (value) => setState(() => _status = value),
                onApply: _applyFilters,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              Text(
                '共 ${page.total} 条评论',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const _EmptyPane(message: '暂无评论')
              else
                for (final comment in page.items) ...[
                  _CommentAdminRow(
                    comment: comment,
                    onDelete:
                        comment.deleted
                            ? null
                            : () => _deleteComment(context, comment),
                    onRestore:
                        comment.deleted
                            ? () => _setStatus(
                              context,
                              comment,
                              AdminCommentStatus.visible,
                            )
                            : null,
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminCommentQuery(
        status: _status,
        contentId: _contentIdController.text.trim(),
        userId: _userIdController.text.trim(),
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _status = null;
      _contentIdController.clear();
      _userIdController.clear();
      _query = const AdminCommentQuery();
    });
  }

  Future<void> _deleteComment(
    BuildContext context,
    AdminCommentItem comment,
  ) async {
    final confirmed = await _confirm(
      context,
      title: '删除评论',
      message: '确认删除这条评论？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminComment(accessToken: token, id: comment.id);
      _refreshCommentState(comment.contentId);
      if (!context.mounted) return;
      _showSnack(context, '评论已删除');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  Future<void> _setStatus(
    BuildContext context,
    AdminCommentItem comment,
    AdminCommentStatus status,
  ) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .updateAdminCommentStatus(
            accessToken: token,
            id: comment.id,
            status: status,
          );
      _refreshCommentState(comment.contentId);
      if (!context.mounted) return;
      _showSnack(
        context,
        status == AdminCommentStatus.visible ? '评论已恢复' : '评论已删除',
      );
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  void _refreshCommentState(String contentId) {
    ref.invalidate(adminCommentsProvider(_query));
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(contentDetailProvider(contentId));
    ref.invalidate(commentsProvider(contentId));
  }
}

/// 评论筛选组件
class _CommentFilters extends StatelessWidget {
  const _CommentFilters({
    required this.status,
    required this.contentIdController,
    required this.userIdController,
    required this.onStatusChanged,
    required this.onApply,
    required this.onClear,
  });

  final AdminCommentStatus? status; // 评论状态筛选
  final TextEditingController contentIdController; // 内容 ID 控制器
  final TextEditingController userIdController; // 用户 ID 控制器
  final ValueChanged<AdminCommentStatus?> onStatusChanged; // 状态变更回调
  final VoidCallback onApply; // 应用筛选回调
  final VoidCallback onClear; // 清空筛选回调

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<AdminCommentStatus?>(
            initialValue: status,
            decoration: const InputDecoration(labelText: '状态'),
            items: const [
              DropdownMenuItem(value: null, child: Text('全部状态')),
              DropdownMenuItem(
                value: AdminCommentStatus.visible,
                child: Text('可见'),
              ),
              DropdownMenuItem(
                value: AdminCommentStatus.deleted,
                child: Text('已删除'),
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ),
        SizedBox(
          width: 300,
          child: TextField(
            controller: contentIdController,
            decoration: const InputDecoration(labelText: '内容 ID'),
          ),
        ),
        SizedBox(
          width: 300,
          child: TextField(
            controller: userIdController,
            decoration: const InputDecoration(labelText: '用户 ID'),
          ),
        ),
        FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('筛选'),
        ),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear),
          label: const Text('清空'),
        ),
      ],
    );
  }
}

/// 评论管理行组件
/// 展示单条评论的内容标题、评论正文、用户信息和操作按钮
class _CommentAdminRow extends StatelessWidget {
  const _CommentAdminRow({
    required this.comment,
    required this.onDelete,
    required this.onRestore,
  });

  final AdminCommentItem comment; // 评论数据
  final VoidCallback? onDelete; // 删除回调（已删除时为 null）
  final VoidCallback? onRestore; // 恢复回调（未删除时为 null）

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDate(comment.createdAt);
    final userLabel =
        comment.userNickname.isEmpty ? comment.userEmail : comment.userNickname;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mode_comment_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap:
                            () => context.go('/contents/${comment.contentId}'),
                        child: Text(
                          comment.contentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        comment.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _CommentStatusChip(status: comment.status),
                _MetaText(icon: Icons.person_outline, text: userLabel),
                if (comment.userEmail.isNotEmpty)
                  _MetaText(icon: Icons.mail_outline, text: comment.userEmail),
                _MetaText(icon: Icons.schedule_outlined, text: createdAt),
                OutlinedButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('恢复'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 点赞管理标签页
/// 支持点赞记录的筛选和删除
class _LikeAdminTab extends ConsumerStatefulWidget {
  const _LikeAdminTab();

  @override
  ConsumerState<_LikeAdminTab> createState() => _LikeAdminTabState();
}

/// 点赞管理标签页状态管理
class _LikeAdminTabState extends ConsumerState<_LikeAdminTab> {
  final _contentIdController = TextEditingController(); // 内容 ID 筛选框
  final _userIdController = TextEditingController(); // 用户 ID 筛选框
  AdminRecordQuery _query = const AdminRecordQuery(); // 当前查询条件

  @override
  void dispose() {
    _contentIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final likes = ref.watch(adminLikesProvider(_query));

    return likes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminLikesProvider(_query)),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SectionToolbar(
                title: '点赞记录',
                actionLabel: '刷新',
                actionIcon: Icons.refresh,
                onAction: () => ref.invalidate(adminLikesProvider(_query)),
              ),
              const SizedBox(height: 12),
              _RecordFilters(
                contentIdController: _contentIdController,
                userIdController: _userIdController,
                onApply: _applyFilters,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              Text(
                '共 ${page.total} 条点赞记录',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const _EmptyPane(message: '暂无点赞记录')
              else
                for (final like in page.items) ...[
                  _LikeAdminRow(
                    like: like,
                    onDelete: () => _deleteLike(context, like),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminRecordQuery(
        contentId: _contentIdController.text.trim(),
        userId: _userIdController.text.trim(),
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _contentIdController.clear();
      _userIdController.clear();
      _query = const AdminRecordQuery();
    });
  }

  Future<void> _deleteLike(BuildContext context, AdminLikeItem like) async {
    final confirmed = await _confirm(
      context,
      title: '删除点赞记录',
      message: '确认删除这条点赞记录？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminLike(accessToken: token, id: like.id);
      _refreshLikeState(like.contentId);
      if (!context.mounted) return;
      _showSnack(context, '点赞记录已删除');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  void _refreshLikeState(String contentId) {
    ref.invalidate(adminLikesProvider(_query));
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(contentDetailProvider(contentId));
    ref.invalidate(recommendationsProvider);
  }
}

/// 浏览记录管理标签页
/// 支持浏览记录的筛选和删除
class _ViewAdminTab extends ConsumerStatefulWidget {
  const _ViewAdminTab();

  @override
  ConsumerState<_ViewAdminTab> createState() => _ViewAdminTabState();
}

/// 浏览记录管理标签页状态管理
class _ViewAdminTabState extends ConsumerState<_ViewAdminTab> {
  final _contentIdController = TextEditingController(); // 内容 ID 筛选框
  final _userIdController = TextEditingController(); // 用户 ID 筛选框
  AdminRecordQuery _query = const AdminRecordQuery(); // 当前查询条件

  @override
  void dispose() {
    _contentIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(adminViewsProvider(_query));

    return views.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminViewsProvider(_query)),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SectionToolbar(
                title: '浏览记录',
                actionLabel: '刷新',
                actionIcon: Icons.refresh,
                onAction: () => ref.invalidate(adminViewsProvider(_query)),
              ),
              const SizedBox(height: 12),
              _RecordFilters(
                contentIdController: _contentIdController,
                userIdController: _userIdController,
                onApply: _applyFilters,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              Text(
                '共 ${page.total} 条浏览记录',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const _EmptyPane(message: '暂无浏览记录')
              else
                for (final view in page.items) ...[
                  _ViewAdminRow(
                    view: view,
                    onDelete: () => _deleteView(context, view),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminRecordQuery(
        contentId: _contentIdController.text.trim(),
        userId: _userIdController.text.trim(),
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _contentIdController.clear();
      _userIdController.clear();
      _query = const AdminRecordQuery();
    });
  }

  Future<void> _deleteView(
    BuildContext context,
    AdminViewRecordItem view,
  ) async {
    final confirmed = await _confirm(
      context,
      title: '删除浏览记录',
      message: '确认删除这条浏览记录？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminView(accessToken: token, id: view.id);
      _refreshViewState(view.contentId);
      if (!context.mounted) return;
      _showSnack(context, '浏览记录已删除');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  void _refreshViewState(String contentId) {
    ref.invalidate(adminViewsProvider(_query));
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(contentDetailProvider(contentId));
  }
}

/// 记录筛选组件
/// 点赞和浏览记录共用的筛选 UI（内容 ID + 用户 ID）
class _RecordFilters extends StatelessWidget {
  const _RecordFilters({
    required this.contentIdController,
    required this.userIdController,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController contentIdController; // 内容 ID 控制器
  final TextEditingController userIdController; // 用户 ID 控制器
  final VoidCallback onApply; // 应用筛选回调
  final VoidCallback onClear; // 清空筛选回调

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: contentIdController,
            decoration: const InputDecoration(labelText: '内容 ID'),
          ),
        ),
        SizedBox(
          width: 300,
          child: TextField(
            controller: userIdController,
            decoration: const InputDecoration(labelText: '用户 ID'),
          ),
        ),
        FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('筛选'),
        ),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear),
          label: const Text('清空'),
        ),
      ],
    );
  }
}

/// 点赞管理行组件
/// 展示单条点赞记录的内容标题、用户信息和删除按钮
class _LikeAdminRow extends StatelessWidget {
  const _LikeAdminRow({required this.like, required this.onDelete});

  final AdminLikeItem like; // 点赞数据
  final VoidCallback onDelete; // 删除回调

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDate(like.createdAt);
    final userLabel =
        like.userNickname.isEmpty ? like.userEmail : like.userNickname;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.favorite_border),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => context.go('/contents/${like.contentId}'),
                    child: Text(
                      like.contentTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaText(icon: Icons.person_outline, text: userLabel),
                if (like.userEmail.isNotEmpty)
                  _MetaText(icon: Icons.mail_outline, text: like.userEmail),
                _MetaText(icon: Icons.schedule_outlined, text: createdAt),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 浏览记录管理行组件
/// 展示单条浏览记录的内容标题、用户信息、User-Agent 和删除按钮
class _ViewAdminRow extends StatelessWidget {
  const _ViewAdminRow({required this.view, required this.onDelete});

  final AdminViewRecordItem view; // 浏览记录数据
  final VoidCallback onDelete; // 删除回调

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDate(view.createdAt);
    final userLabel =
        view.anonymous
            ? '匿名访客'
            : (view.userNickname.isEmpty ? view.userEmail : view.userNickname);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.history_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => context.go('/contents/${view.contentId}'),
                    child: Text(
                      view.contentTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (view.userAgent.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                view.userAgent,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaText(icon: Icons.person_outline, text: userLabel),
                if (view.userEmail.isNotEmpty)
                  _MetaText(icon: Icons.mail_outline, text: view.userEmail),
                if (view.anonymousId.isNotEmpty)
                  _MetaText(icon: Icons.fingerprint, text: view.anonymousId),
                _MetaText(icon: Icons.schedule_outlined, text: createdAt),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 用户管理标签页
/// 支持用户的筛选、编辑和禁用操作
class _UserAdminTab extends ConsumerStatefulWidget {
  const _UserAdminTab();

  @override
  ConsumerState<_UserAdminTab> createState() => _UserAdminTabState();
}

/// 用户管理标签页状态管理
class _UserAdminTabState extends ConsumerState<_UserAdminTab> {
  final _queryController = TextEditingController(); // 搜索关键词输入框
  AdminUserRole? _role; // 角色筛选
  AdminUserStatus? _status; // 状态筛选
  AdminUserQuery _query = const AdminUserQuery(); // 当前查询条件

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider(_query));
    final currentUserId = ref.watch(authControllerProvider).user?.id;

    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminUsersProvider(_query)),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SectionToolbar(
                title: '用户管理',
                actionLabel: '刷新',
                actionIcon: Icons.refresh,
                onAction: () => ref.invalidate(adminUsersProvider(_query)),
              ),
              const SizedBox(height: 12),
              _UserFilters(
                queryController: _queryController,
                role: _role,
                status: _status,
                onRoleChanged: (value) => setState(() => _role = value),
                onStatusChanged: (value) => setState(() => _status = value),
                onApply: _applyFilters,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              Text(
                '共 ${page.total} 个用户',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const _EmptyPane(message: '暂无用户')
              else
                for (final user in page.items) ...[
                  _UserAdminRow(
                    user: user,
                    isCurrentUser: user.id == currentUserId,
                    onEdit: () => _openUserEditor(context, user),
                    onDisable:
                        user.id == currentUserId || user.disabled
                            ? null
                            : () => _disableUser(context, user),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminUserQuery(
        query: _queryController.text.trim(),
        role: _role,
        status: _status,
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _queryController.clear();
      _role = null;
      _status = null;
      _query = const AdminUserQuery();
    });
  }

  Future<void> _openUserEditor(BuildContext context, AdminUserItem user) async {
    final draft = await showDialog<AdminUserDraft>(
      context: context,
      builder: (context) => _UserEditorDialog(user: user),
    );
    if (draft == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .updateAdminUser(accessToken: token, id: user.id, draft: draft);
      _refreshUserState();
      if (!context.mounted) return;
      _showSnack(context, '用户已保存');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  Future<void> _disableUser(BuildContext context, AdminUserItem user) async {
    final confirmed = await _confirm(
      context,
      title: '禁用用户',
      message: '确认禁用「${user.nickname}」？',
      action: '禁用',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminUser(accessToken: token, id: user.id);
      _refreshUserState();
      if (!context.mounted) return;
      _showSnack(context, '用户已禁用');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  void _refreshUserState() {
    ref.invalidate(adminUsersProvider(_query));
    ref.invalidate(adminDashboardProvider);
  }
}

/// 用户筛选组件
class _UserFilters extends StatelessWidget {
  const _UserFilters({
    required this.queryController,
    required this.role,
    required this.status,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController queryController; // 搜索关键词控制器
  final AdminUserRole? role; // 角色筛选
  final AdminUserStatus? status; // 状态筛选
  final ValueChanged<AdminUserRole?> onRoleChanged; // 角色变更回调
  final ValueChanged<AdminUserStatus?> onStatusChanged; // 状态变更回调
  final VoidCallback onApply; // 应用筛选回调
  final VoidCallback onClear; // 清空筛选回调

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: queryController,
            decoration: const InputDecoration(labelText: '邮箱 / 昵称'),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<AdminUserRole?>(
            initialValue: role,
            decoration: const InputDecoration(labelText: '角色'),
            items: const [
              DropdownMenuItem(value: null, child: Text('全部角色')),
              DropdownMenuItem(value: AdminUserRole.user, child: Text('普通用户')),
              DropdownMenuItem(value: AdminUserRole.admin, child: Text('管理员')),
            ],
            onChanged: onRoleChanged,
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<AdminUserStatus?>(
            initialValue: status,
            decoration: const InputDecoration(labelText: '状态'),
            items: const [
              DropdownMenuItem(value: null, child: Text('全部状态')),
              DropdownMenuItem(
                value: AdminUserStatus.active,
                child: Text('启用'),
              ),
              DropdownMenuItem(
                value: AdminUserStatus.disabled,
                child: Text('禁用'),
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ),
        FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('筛选'),
        ),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear),
          label: const Text('清空'),
        ),
      ],
    );
  }
}

/// 用户管理行组件
/// 展示单条用户的头像、昵称、邮箱、角色、状态和操作按钮
class _UserAdminRow extends StatelessWidget {
  const _UserAdminRow({
    required this.user,
    required this.isCurrentUser,
    required this.onEdit,
    required this.onDisable,
  });

  final AdminUserItem user; // 用户数据
  final bool isCurrentUser; // 是否为当前登录用户
  final VoidCallback onEdit; // 编辑回调
  final VoidCallback? onDisable; // 禁用回调（当前用户或已禁用时为 null）

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDate(user.createdAt);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminUserAvatar(user: user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (isCurrentUser) const Chip(label: Text('当前账号')),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user.bio.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          user.bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _UserRoleChip(role: user.role),
                _UserStatusChip(status: user.status),
                if (user.blogUrl.isNotEmpty)
                  _MetaText(icon: Icons.link_outlined, text: user.blogUrl),
                _MetaText(icon: Icons.schedule_outlined, text: createdAt),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
                OutlinedButton.icon(
                  onPressed: onDisable,
                  icon: const Icon(Icons.block),
                  label: const Text('禁用'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 管理后台用户头像组件
/// 显示用户头像，无头像时显示昵称首字符
class _AdminUserAvatar extends StatelessWidget {
  const _AdminUserAvatar({required this.user});

  final AdminUserItem user; // 用户数据

  @override
  Widget build(BuildContext context) {
    final fallback =
        user.nickname.isEmpty ? '?' : user.nickname.substring(0, 1);
    if (user.avatarUrl.isEmpty) {
      return CircleAvatar(radius: 24, child: Text(fallback));
    }
    return CircleAvatar(
      radius: 24,
      backgroundImage: NetworkImage(user.avatarUrl),
      onBackgroundImageError: (_, _) {},
      child: null,
    );
  }
}

/// AI 聊天记录管理标签页
/// 支持 AI 会话的查看、删除和筛选
class _AiChatAdminTab extends ConsumerStatefulWidget {
  const _AiChatAdminTab();

  @override
  ConsumerState<_AiChatAdminTab> createState() => _AiChatAdminTabState();
}

/// AI 聊天记录管理标签页状态管理
class _AiChatAdminTabState extends ConsumerState<_AiChatAdminTab> {
  final _queryController = TextEditingController(); // 搜索关键词输入框
  final _userIdController = TextEditingController(); // 用户 ID 筛选框
  AdminAiChatQuery _query = const AdminAiChatQuery(); // 当前查询条件

  @override
  void dispose() {
    _queryController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(adminAiChatsProvider(_query));

    return chats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminAiChatsProvider(_query)),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SectionToolbar(
                title: 'AI 聊天记录',
                actionLabel: '刷新',
                actionIcon: Icons.refresh,
                onAction: () => ref.invalidate(adminAiChatsProvider(_query)),
              ),
              const SizedBox(height: 12),
              _AiChatFilters(
                queryController: _queryController,
                userIdController: _userIdController,
                onApply: _applyFilters,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              Text(
                '共 ${page.total} 个 AI 会话',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const _EmptyPane(message: '暂无 AI 聊天记录')
              else
                for (final session in page.items) ...[
                  _AiChatAdminRow(
                    session: session,
                    onOpen: () => _openChatDetail(context, session),
                    onDelete: () => _deleteChat(context, session),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
    );
  }

  void _applyFilters() {
    setState(() {
      _query = AdminAiChatQuery(
        query: _queryController.text.trim(),
        userId: _userIdController.text.trim(),
      );
    });
  }

  void _clearFilters() {
    setState(() {
      _queryController.clear();
      _userIdController.clear();
      _query = const AdminAiChatQuery();
    });
  }

  Future<void> _openChatDetail(
    BuildContext context,
    AdminAiChatSessionItem session,
  ) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      final detail = await ref
          .read(apiClientProvider)
          .fetchAdminAiChatDetail(accessToken: token, id: session.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _AiChatDetailDialog(detail: detail),
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      _showSnack(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, error.toString());
    }
  }

  Future<void> _deleteChat(
    BuildContext context,
    AdminAiChatSessionItem session,
  ) async {
    final title = session.title.isEmpty ? '未命名会话' : session.title;
    final confirmed = await _confirm(
      context,
      title: '删除 AI 会话',
      message: '确认删除「$title」及其消息记录？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminAiChat(accessToken: token, id: session.id);
      _refreshAiChatState();
      if (!context.mounted) return;
      _showSnack(context, 'AI 会话已删除');
    } on ApiException catch (error) {
      _showSnack(context, error.message);
    } catch (error) {
      _showSnack(context, error.toString());
    }
  }

  void _refreshAiChatState() {
    ref.invalidate(adminAiChatsProvider(_query));
    ref.invalidate(adminDashboardProvider);
  }
}

/// AI 聊天筛选组件
class _AiChatFilters extends StatelessWidget {
  const _AiChatFilters({
    required this.queryController,
    required this.userIdController,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController queryController; // 搜索关键词控制器
  final TextEditingController userIdController; // 用户 ID 控制器
  final VoidCallback onApply; // 应用筛选回调
  final VoidCallback onClear; // 清空筛选回调

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: queryController,
            decoration: const InputDecoration(labelText: '标题 / 用户'),
          ),
        ),
        SizedBox(
          width: 300,
          child: TextField(
            controller: userIdController,
            decoration: const InputDecoration(labelText: '用户 ID'),
          ),
        ),
        FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('筛选'),
        ),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear),
          label: const Text('清空'),
        ),
      ],
    );
  }
}

/// AI 聊天管理行组件
/// 展示单条 AI 会话的标题、最后消息、用户和操作按钮
class _AiChatAdminRow extends StatelessWidget {
  const _AiChatAdminRow({
    required this.session,
    required this.onOpen,
    required this.onDelete,
  });

  final AdminAiChatSessionItem session; // 会话数据
  final VoidCallback onOpen; // 查看详情回调
  final VoidCallback onDelete; // 删除回调

  @override
  Widget build(BuildContext context) {
    final title = session.title.isEmpty ? '未命名会话' : session.title;
    final userLabel =
        session.userNickname.isEmpty ? session.userEmail : session.userNickname;
    final lastMessage =
        session.lastMessage.isEmpty ? '暂无消息' : session.lastMessage;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.smart_toy_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        lastMessage,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaText(icon: Icons.person_outline, text: userLabel),
                if (session.userEmail.isNotEmpty)
                  _MetaText(icon: Icons.mail_outline, text: session.userEmail),
                _MetaText(
                  icon: Icons.forum_outlined,
                  text: '${session.messageCount} 条消息',
                ),
                _MetaText(
                  icon: Icons.update,
                  text: _formatDate(session.updatedAt),
                ),
                OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('查看'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// AI 聊天详情对话框
/// 展示 AI 会话的完整消息列表
class _AiChatDetailDialog extends StatelessWidget {
  const _AiChatDetailDialog({required this.detail});

  final AdminAiChatDetail detail; // 会话详情数据

  @override
  Widget build(BuildContext context) {
    final session = detail.session;
    final title = session.title.isEmpty ? '未命名会话' : session.title;
    final userLabel =
        session.userNickname.isEmpty ? session.userEmail : session.userNickname;
    return AlertDialog(
      title: const Text('AI 聊天详情'),
      content: SizedBox(
        width: 760,
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaText(icon: Icons.person_outline, text: userLabel),
                if (session.userEmail.isNotEmpty)
                  _MetaText(icon: Icons.mail_outline, text: session.userEmail),
                _MetaText(
                  icon: Icons.forum_outlined,
                  text: '${session.messageCount} 条消息',
                ),
                _MetaText(
                  icon: Icons.schedule_outlined,
                  text: _formatDate(session.createdAt),
                ),
              ],
            ),
            const Divider(height: 28),
            Expanded(
              child:
                  detail.messages.isEmpty
                      ? const _EmptyPane(message: '暂无消息')
                      : ListView.separated(
                        itemCount: detail.messages.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 10),
                        itemBuilder:
                            (context, index) => _AiChatMessageRow(
                              message: detail.messages[index],
                            ),
                      ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.check),
          label: const Text('关闭'),
        ),
      ],
    );
  }
}

/// AI 聊天消息行组件
/// 根据消息角色（用户/助手/工具/系统）显示不同背景色
class _AiChatMessageRow extends StatelessWidget {
  const _AiChatMessageRow({required this.message});

  final AdminAiChatMessageItem message; // 消息数据

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (message.role) {
      AiChatMessageRole.user => scheme.secondaryContainer,
      AiChatMessageRole.assistant => scheme.primaryContainer,
      AiChatMessageRole.tool => scheme.tertiaryContainer,
      AiChatMessageRole.system => scheme.surfaceContainerHighest,
    };
    final tokenText = [
      if (message.promptTokens > 0) 'prompt ${message.promptTokens}',
      if (message.completionTokens > 0)
        'completion ${message.completionTokens}',
    ].join(' / ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _AiRoleChip(role: message.role),
                _MetaText(
                  icon: Icons.schedule_outlined,
                  text: _formatDate(message.createdAt),
                ),
                if (message.toolName.isNotEmpty)
                  _MetaText(icon: Icons.build_outlined, text: message.toolName),
                if (tokenText.isNotEmpty)
                  _MetaText(icon: Icons.data_usage, text: tokenText),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(message.content),
          ],
        ),
      ),
    );
  }
}

/// AI 消息角色标签组件
class _AiRoleChip extends StatelessWidget {
  const _AiRoleChip({required this.role});

  final AiChatMessageRole role; // 消息角色

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (role) {
      AiChatMessageRole.user => scheme.secondaryContainer,
      AiChatMessageRole.assistant => scheme.primaryContainer,
      AiChatMessageRole.tool => scheme.tertiaryContainer,
      AiChatMessageRole.system => scheme.surfaceContainerHighest,
    };
    return Chip(label: Text(role.label), backgroundColor: color);
  }
}

/// 知识库管理标签页
/// 支持知识库文档的新增、编辑、删除和筛选
class _KnowledgeAdminTab extends ConsumerStatefulWidget {
  const _KnowledgeAdminTab();

  @override
  ConsumerState<_KnowledgeAdminTab> createState() => _KnowledgeAdminTabState();
}

/// 知识库管理标签页状态管理
class _KnowledgeAdminTabState extends ConsumerState<_KnowledgeAdminTab> {
  final _queryController = TextEditingController(); // 搜索关键词输入框
  bool? _enabled; // 启用状态筛选
  AdminKnowledgeDocQuery _query = const AdminKnowledgeDocQuery(); // 当前查询条件

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(adminKnowledgeDocsProvider(_query));

    return docs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminKnowledgeDocsProvider(_query)),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SectionToolbar(
                title: '个人知识库',
                actionLabel: '新增',
                actionIcon: Icons.add,
                onAction: () => _openKnowledgeEditor(context),
                secondaryLabel: '刷新',
                secondaryIcon: Icons.refresh,
                onSecondaryAction:
                    () => ref.invalidate(adminKnowledgeDocsProvider(_query)),
              ),
              const SizedBox(height: 12),
              _KnowledgeFilters(
                queryController: _queryController,
                enabled: _enabled,
                onEnabledChanged: (value) => setState(() => _enabled = value),
                onApply: _applyFilters,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              Text(
                '共 ${page.total} 篇知识库文档',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (page.items.isEmpty)
                const _EmptyPane(message: '暂无知识库文档')
              else
                for (final doc in page.items) ...[
                  _KnowledgeDocRow(
                    doc: doc,
                    onEdit: () => _openKnowledgeEditor(context, doc: doc),
                    onDelete: () => _deleteKnowledgeDoc(context, doc),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
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

  Future<void> _openKnowledgeEditor(
    BuildContext context, {
    AdminKnowledgeDocItem? doc,
  }) async {
    final draft = await showDialog<AdminKnowledgeDocDraft>(
      context: context,
      builder: (context) => _KnowledgeEditorDialog(doc: doc),
    );
    if (draft == null || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      if (doc == null) {
        await ref
            .read(apiClientProvider)
            .createAdminKnowledgeDoc(accessToken: token, draft: draft);
      } else {
        await ref
            .read(apiClientProvider)
            .updateAdminKnowledgeDoc(
              accessToken: token,
              id: doc.id,
              draft: draft,
            );
      }
      _refreshKnowledgeState();
      if (!context.mounted) return;
      _showSnack(context, doc == null ? '知识库文档已创建' : '知识库文档已保存');
    } on ApiException catch (error) {
      if (!context.mounted) return;
      _showSnack(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, error.toString());
    }
  }

  Future<void> _deleteKnowledgeDoc(
    BuildContext context,
    AdminKnowledgeDocItem doc,
  ) async {
    final confirmed = await _confirm(
      context,
      title: '删除知识库文档',
      message: '确认删除「${doc.title}」？',
      action: '删除',
    );
    if (!confirmed || !context.mounted) return;

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteAdminKnowledgeDoc(accessToken: token, id: doc.id);
      _refreshKnowledgeState();
      if (!context.mounted) return;
      _showSnack(context, '知识库文档已删除');
    } on ApiException catch (error) {
      if (!context.mounted) return;
      _showSnack(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, error.toString());
    }
  }

  void _refreshKnowledgeState() {
    ref.invalidate(adminKnowledgeDocsProvider(_query));
    ref.invalidate(adminDashboardProvider);
  }
}

/// 知识库筛选组件
class _KnowledgeFilters extends StatelessWidget {
  const _KnowledgeFilters({
    required this.queryController,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController queryController; // 搜索关键词控制器
  final bool? enabled; // 启用状态
  final ValueChanged<bool?> onEnabledChanged; // 状态变更回调
  final VoidCallback onApply; // 应用筛选回调
  final VoidCallback onClear; // 清空筛选回调

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: queryController,
            decoration: const InputDecoration(labelText: '标题 / 来源 / 正文'),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<bool?>(
            initialValue: enabled,
            decoration: const InputDecoration(labelText: '状态'),
            items: const [
              DropdownMenuItem(value: null, child: Text('全部状态')),
              DropdownMenuItem(value: true, child: Text('启用')),
              DropdownMenuItem(value: false, child: Text('停用')),
            ],
            onChanged: onEnabledChanged,
          ),
        ),
        FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('筛选'),
        ),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear),
          label: const Text('清空'),
        ),
      ],
    );
  }
}

/// 知识库文档行组件
/// 展示单条知识库文档的标题、正文预览、来源类型和操作按钮
class _KnowledgeDocRow extends StatelessWidget {
  const _KnowledgeDocRow({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminKnowledgeDocItem doc; // 文档数据
  final VoidCallback onEdit; // 编辑回调
  final VoidCallback onDelete; // 删除回调

  @override
  Widget build(BuildContext context) {
    final preview = doc.body.isEmpty ? '暂无正文' : doc.body;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.library_books_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _KnowledgeSourceChip(sourceType: doc.sourceType),
                _KnowledgeEnabledChip(enabled: doc.enabled),
                if (doc.sourceRef.isNotEmpty)
                  _MetaText(icon: Icons.link_outlined, text: doc.sourceRef),
                _MetaText(icon: Icons.update, text: _formatDate(doc.updatedAt)),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 知识库编辑器对话框
/// 支持新增和编辑知识库文档，包含标题、来源类型、来源引用、正文和启用状态
class _KnowledgeEditorDialog extends StatefulWidget {
  const _KnowledgeEditorDialog({required this.doc});

  final AdminKnowledgeDocItem? doc; // 待编辑文档（null 表示新增）

  @override
  State<_KnowledgeEditorDialog> createState() => _KnowledgeEditorDialogState();
}

class _KnowledgeEditorDialogState extends State<_KnowledgeEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sourceRefController = TextEditingController();
  final _bodyController = TextEditingController();
  late KnowledgeSourceType _sourceType;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final doc = widget.doc;
    final draft =
        doc == null
            ? const AdminKnowledgeDocDraft(
              title: '',
              sourceType: KnowledgeSourceType.manual,
              sourceRef: '',
              body: '',
              enabled: true,
            )
            : AdminKnowledgeDocDraft.fromItem(doc);
    _titleController.text = draft.title;
    _sourceType = draft.sourceType;
    _sourceRefController.text = draft.sourceRef;
    _bodyController.text = draft.body;
    _enabled = draft.enabled;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sourceRefController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.doc == null ? '新增知识库文档' : '编辑知识库文档'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '标题'),
                  maxLength: 180,
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? '请输入标题'
                              : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<KnowledgeSourceType>(
                  initialValue: _sourceType,
                  decoration: const InputDecoration(labelText: '来源类型'),
                  items: [
                    for (final sourceType in KnowledgeSourceType.values)
                      DropdownMenuItem(
                        value: sourceType,
                        child: Text(sourceType.label),
                      ),
                  ],
                  onChanged:
                      (value) => setState(
                        () => _sourceType = value ?? KnowledgeSourceType.manual,
                      ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sourceRefController,
                  decoration: const InputDecoration(labelText: '来源引用'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(labelText: '知识正文'),
                  minLines: 8,
                  maxLines: 16,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启用'),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AdminKnowledgeDocDraft(
        title: _titleController.text,
        sourceType: _sourceType,
        sourceRef: _sourceRefController.text,
        body: _bodyController.text,
        enabled: _enabled,
      ),
    );
  }
}

/// 知识库来源类型标签组件
class _KnowledgeSourceChip extends StatelessWidget {
  const _KnowledgeSourceChip({required this.sourceType});

  final KnowledgeSourceType sourceType; // 来源类型

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (sourceType) {
      KnowledgeSourceType.manual => scheme.secondaryContainer,
      KnowledgeSourceType.url => scheme.primaryContainer,
      KnowledgeSourceType.file => scheme.tertiaryContainer,
      KnowledgeSourceType.content => scheme.surfaceContainerHighest,
    };
    return Chip(label: Text(sourceType.label), backgroundColor: color);
  }
}

/// 知识库启用状态标签组件
class _KnowledgeEnabledChip extends StatelessWidget {
  const _KnowledgeEnabledChip({required this.enabled});

  final bool enabled; // 是否启用

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(enabled ? '启用' : '停用'),
      backgroundColor:
          enabled ? scheme.primaryContainer : scheme.errorContainer,
    );
  }
}

/// 区域工具栏组件
/// 显示区域标题和操作按钮（支持主/副两个按钮）
class _SectionToolbar extends StatelessWidget {
  const _SectionToolbar({
    required this.title,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondaryAction,
  });

  final String title; // 区域标题
  final String actionLabel; // 主按钮文本
  final IconData actionIcon; // 主按钮图标
  final VoidCallback onAction; // 主按钮点击回调
  final String? secondaryLabel; // 副按钮文本
  final IconData? secondaryIcon; // 副按钮图标
  final VoidCallback? onSecondaryAction; // 副按钮点击回调

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            if (secondaryLabel != null)
              OutlinedButton.icon(
                onPressed: onSecondaryAction,
                icon: Icon(secondaryIcon ?? Icons.add),
                label: Text(secondaryLabel!),
              ),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon),
              label: Text(actionLabel),
            ),
          ],
        ),
      ],
    );
  }
}

/// 内容编辑器对话框
/// 支持新增和编辑内容，包含标题、Slug、类型、状态、置顶、摘要、正文和标签
class _ContentEditorDialog extends StatefulWidget {
  const _ContentEditorDialog({required this.content, required this.tags});

  final AdminContentItem? content; // 待编辑内容（null 表示新增）
  final List<TagItem> tags; // 可选标签列表

  @override
  State<_ContentEditorDialog> createState() => _ContentEditorDialogState();
}

/// 内容编辑器对话框状态管理
class _ContentEditorDialogState extends State<_ContentEditorDialog> {
  final _formKey = GlobalKey<FormState>(); // 表单 Key
  final _titleController = TextEditingController(); // 标题输入框
  final _slugController = TextEditingController(); // Slug 输入框
  final _summaryController = TextEditingController(); // 摘要输入框
  final _bodyController = TextEditingController(); // Markdown 正文输入框
  late ContentType _type; // 内容类型
  late ContentStatus _status; // 内容状态
  late bool _pinned; // 是否置顶
  late Set<String> _tagSlugs; // 已选标签 Slug 集合

  @override
  void initState() {
    super.initState();
    final content = widget.content;
    final draft =
        content == null
            ? const AdminContentDraft(
              title: '',
              slug: '',
              type: ContentType.article,
              status: ContentStatus.draft,
              summary: '',
              bodyMarkdown: '',
              pinned: false,
              tagSlugs: [],
            )
            : AdminContentDraft.fromItem(content);
    _titleController.text = draft.title;
    _slugController.text = draft.slug;
    _summaryController.text = draft.summary;
    _bodyController.text = draft.bodyMarkdown;
    _type = draft.type;
    _status = draft.status;
    _pinned = draft.pinned;
    _tagSlugs = draft.tagSlugs.toSet();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.content == null ? '新增内容' : '编辑内容'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '标题'),
                  maxLength: 180,
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? '请输入标题'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(labelText: 'Slug'),
                  maxLength: 220,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<ContentType>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: '类型'),
                        items: [
                          for (final type in ContentType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                        ],
                        onChanged:
                            (value) => setState(
                              () => _type = value ?? ContentType.article,
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<ContentStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: '状态'),
                        items: [
                          for (final status in ContentStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged:
                            (value) => setState(
                              () => _status = value ?? ContentStatus.draft,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('置顶'),
                  value: _pinned,
                  onChanged: (value) => setState(() => _pinned = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summaryController,
                  decoration: const InputDecoration(labelText: '摘要'),
                  maxLines: 3,
                  maxLength: 2000,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(labelText: 'Markdown 内容'),
                  minLines: 6,
                  maxLines: 12,
                ),
                if (widget.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in widget.tags)
                        FilterChip(
                          label: Text(tag.name),
                          selected: _tagSlugs.contains(tag.slug),
                          onSelected:
                              (selected) => setState(() {
                                if (selected) {
                                  _tagSlugs.add(tag.slug);
                                } else {
                                  _tagSlugs.remove(tag.slug);
                                }
                              }),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AdminContentDraft(
        title: _titleController.text,
        slug: _slugController.text,
        type: _type,
        status: _status,
        summary: _summaryController.text,
        bodyMarkdown: _bodyController.text,
        pinned: _pinned,
        tagSlugs: _tagSlugs.toList()..sort(),
      ),
    );
  }
}

/// 上传媒体草稿数据
class _UploadMediaDraft {
  const _UploadMediaDraft({required this.contentId, required this.type});

  final String contentId; // 绑定的内容 ID
  final MediaAssetType type; // 媒体类型
}

/// 上传媒体对话框
/// 选择文件后弹出，用于指定媒体类型和绑定内容
class _UploadMediaDialog extends StatefulWidget {
  const _UploadMediaDialog({
    required this.filename,
    required this.inferredType,
    required this.contents,
  });

  final String filename; // 文件名
  final MediaAssetType inferredType; // 根据文件名推断的媒体类型
  final List<AdminContentItem> contents; // 可绑定的内容列表

  @override
  State<_UploadMediaDialog> createState() => _UploadMediaDialogState();
}

class _UploadMediaDialogState extends State<_UploadMediaDialog> {
  late String _contentId;
  late MediaAssetType _type;

  @override
  void initState() {
    super.initState();
    _contentId = '';
    _type = widget.inferredType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('上传文件'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(
                widget.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('文件会上传到 MinIO 并自动写入媒体库'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _contentId,
              decoration: const InputDecoration(labelText: '绑定内容'),
              items: [
                const DropdownMenuItem(value: '', child: Text('不绑定内容')),
                for (final content in widget.contents)
                  DropdownMenuItem(
                    value: content.id,
                    child: Text(
                      content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _contentId = value ?? ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MediaAssetType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '媒体类型'),
              items: [
                for (final type in MediaAssetType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged:
                  (value) =>
                      setState(() => _type = value ?? MediaAssetType.file),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed:
              () => Navigator.of(
                context,
              ).pop(_UploadMediaDraft(contentId: _contentId, type: _type)),
          icon: const Icon(Icons.upload_file),
          label: const Text('上传'),
        ),
      ],
    );
  }
}

/// 媒体编辑器对话框
/// 支持新增和编辑媒体资源，包含 URL、文件名、MIME 类型和尺寸信息
class _MediaEditorDialog extends StatefulWidget {
  const _MediaEditorDialog({required this.media, required this.contents});

  final AdminMediaItem? media; // 待编辑媒体（null 表示新增）
  final List<AdminContentItem> contents; // 可绑定的内容列表

  @override
  State<_MediaEditorDialog> createState() => _MediaEditorDialogState();
}

class _MediaEditorDialogState extends State<_MediaEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _filenameController = TextEditingController();
  final _contentTypeController = TextEditingController();
  final _byteSizeController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _durationController = TextEditingController();
  late MediaAssetType _type;
  late String _contentId;

  @override
  void initState() {
    super.initState();
    final media = widget.media;
    final draft =
        media == null
            ? const AdminMediaDraft(
              contentId: '',
              type: MediaAssetType.image,
              publicUrl: '',
              filename: '',
              contentType: 'image/jpeg',
              byteSize: null,
              width: null,
              height: null,
              durationSeconds: null,
            )
            : AdminMediaDraft.fromItem(media);
    final knownContent = widget.contents.any(
      (content) => content.id == draft.contentId,
    );
    _contentId = knownContent ? draft.contentId : '';
    _type = draft.type;
    _urlController.text = draft.publicUrl;
    _filenameController.text = draft.filename;
    _contentTypeController.text = draft.contentType;
    _byteSizeController.text = draft.byteSize?.toString() ?? '';
    _widthController.text = draft.width?.toString() ?? '';
    _heightController.text = draft.height?.toString() ?? '';
    _durationController.text = draft.durationSeconds?.toString() ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    _filenameController.dispose();
    _contentTypeController.dispose();
    _byteSizeController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.media == null ? '新增媒体' : '编辑媒体'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _contentId,
                  decoration: const InputDecoration(labelText: '绑定内容'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('不绑定内容')),
                    for (final content in widget.contents)
                      DropdownMenuItem(
                        value: content.id,
                        child: Text(
                          content.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged:
                      (value) => setState(() => _contentId = value ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MediaAssetType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: '媒体类型'),
                  items: [
                    for (final type in MediaAssetType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged:
                      (value) =>
                          setState(() => _type = value ?? MediaAssetType.image),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: '媒体 URL'),
                  validator: _validateUrl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _filenameController,
                  decoration: const InputDecoration(labelText: '文件名'),
                  maxLength: 240,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contentTypeController,
                  decoration: const InputDecoration(labelText: 'MIME 类型'),
                  maxLength: 120,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _NumberField(controller: _byteSizeController, label: '字节数'),
                    _NumberField(controller: _widthController, label: '宽度'),
                    _NumberField(controller: _heightController, label: '高度'),
                    _NumberField(controller: _durationController, label: '时长秒'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
      ],
    );
  }

  String? _validateUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入媒体 URL';
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) return '请输入完整 URL';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AdminMediaDraft(
        contentId: _contentId,
        type: _type,
        publicUrl: _urlController.text,
        filename: _filenameController.text,
        contentType: _contentTypeController.text,
        byteSize: _parseNullableInt(_byteSizeController.text),
        width: _parseNullableInt(_widthController.text),
        height: _parseNullableInt(_heightController.text),
        durationSeconds: _parseNullableInt(_durationController.text),
      ),
    );
  }
}

/// 数字输入框组件
/// 带数字验证的文本输入框
class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller; // 输入框控制器
  final String label; // 标签文本

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return null;
          return int.tryParse(text) == null ? '请输入数字' : null;
        },
      ),
    );
  }
}

/// 友链编辑器对话框
/// 支持新增和编辑友链，包含名称、站点 URL、头像、简介、排序和可见性
class _FriendEditorDialog extends StatefulWidget {
  const _FriendEditorDialog({required this.friend});

  final FriendLink? friend; // 待编辑友链（null 表示新增）

  @override
  State<_FriendEditorDialog> createState() => _FriendEditorDialogState();
}

class _FriendEditorDialogState extends State<_FriendEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _introController = TextEditingController();
  final _avatarController = TextEditingController();
  final _siteController = TextEditingController();
  final _sortController = TextEditingController();
  late bool _visible;

  @override
  void initState() {
    super.initState();
    final friend = widget.friend;
    final draft =
        friend == null
            ? const FriendDraft(
              name: '',
              intro: '',
              avatarUrl: '',
              siteUrl: '',
              visible: true,
              sortOrder: 0,
            )
            : FriendDraft.fromItem(friend);
    _nameController.text = draft.name;
    _introController.text = draft.intro;
    _avatarController.text = draft.avatarUrl;
    _siteController.text = draft.siteUrl;
    _sortController.text = draft.sortOrder.toString();
    _visible = draft.visible;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _introController.dispose();
    _avatarController.dispose();
    _siteController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.friend == null ? '新增朋友' : '编辑朋友'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                  maxLength: 80,
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? '请输入名称'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _siteController,
                  decoration: const InputDecoration(labelText: '站点 URL'),
                  validator: _validateRequiredUrl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _avatarController,
                  decoration: const InputDecoration(labelText: '头像 URL'),
                  validator: _validateOptionalUrl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _introController,
                  decoration: const InputDecoration(labelText: '简介'),
                  maxLines: 3,
                  maxLength: 1000,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sortController,
                  decoration: const InputDecoration(labelText: '排序值'),
                  keyboardType: TextInputType.number,
                  validator:
                      (value) =>
                          int.tryParse(value?.trim() ?? '') == null
                              ? '请输入数字'
                              : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('公开展示'),
                  value: _visible,
                  onChanged: (value) => setState(() => _visible = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
      ],
    );
  }

  String? _validateRequiredUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入站点 URL';
    return _validateUrlText(text);
  }

  String? _validateOptionalUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return _validateUrlText(text);
  }

  String? _validateUrlText(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) return '请输入完整 URL';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      FriendDraft(
        name: _nameController.text,
        intro: _introController.text,
        avatarUrl: _avatarController.text,
        siteUrl: _siteController.text,
        visible: _visible,
        sortOrder: int.parse(_sortController.text.trim()),
      ),
    );
  }
}

/// 用户编辑器对话框
/// 编辑用户信息，包含邮箱、昵称、头像、简介、博客地址、角色和状态
class _UserEditorDialog extends StatefulWidget {
  const _UserEditorDialog({required this.user});

  final AdminUserItem user; // 待编辑用户

  @override
  State<_UserEditorDialog> createState() => _UserEditorDialogState();
}

class _UserEditorDialogState extends State<_UserEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _avatarController = TextEditingController();
  final _bioController = TextEditingController();
  final _blogUrlController = TextEditingController();
  late AdminUserRole _role;
  late AdminUserStatus _status;

  @override
  void initState() {
    super.initState();
    final draft = AdminUserDraft.fromItem(widget.user);
    _emailController.text = draft.email;
    _nicknameController.text = draft.nickname;
    _avatarController.text = draft.avatarUrl;
    _bioController.text = draft.bio;
    _blogUrlController.text = draft.blogUrl;
    _role = draft.role;
    _status = draft.status;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _avatarController.dispose();
    _bioController.dispose();
    _blogUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑用户'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: '邮箱'),
                  maxLength: 320,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(labelText: '昵称'),
                  maxLength: 80,
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? '请输入昵称'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _avatarController,
                  decoration: const InputDecoration(labelText: '头像 URL'),
                  validator: _validateOptionalUrl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _blogUrlController,
                  decoration: const InputDecoration(labelText: '博客地址'),
                  validator: _validateOptionalUrl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(labelText: '简介'),
                  maxLines: 3,
                  maxLength: 2000,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<AdminUserRole>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: '角色'),
                        items: [
                          for (final role in AdminUserRole.values)
                            DropdownMenuItem(
                              value: role,
                              child: Text(role.label),
                            ),
                        ],
                        onChanged:
                            (value) => setState(
                              () => _role = value ?? AdminUserRole.user,
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<AdminUserStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: '状态'),
                        items: [
                          for (final status in AdminUserStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged:
                            (value) => setState(
                              () => _status = value ?? AdminUserStatus.active,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
      ],
    );
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入邮箱';
    if (!text.contains('@')) return '请输入有效邮箱';
    return null;
  }

  String? _validateOptionalUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme) return '请输入完整 URL';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AdminUserDraft(
        email: _emailController.text,
        nickname: _nicknameController.text,
        avatarUrl: _avatarController.text,
        bio: _bioController.text,
        blogUrl: _blogUrlController.text,
        role: _role,
        status: _status,
      ),
    );
  }
}

/// 标签编辑器对话框
/// 支持新增和编辑标签，包含名称、Slug 和描述
class _TagEditorDialog extends StatefulWidget {
  const _TagEditorDialog({required this.tag});

  final TagItem? tag; // 待编辑标签（null 表示新增）

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final tag = widget.tag;
    if (tag != null) {
      _nameController.text = tag.name;
      _slugController.text = tag.slug;
      _descriptionController.text = tag.description;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tag == null ? '新增标签' : '编辑标签'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '名称'),
                maxLength: 60,
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty ? '请输入名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _slugController,
                decoration: const InputDecoration(labelText: 'Slug'),
                maxLength: 80,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: '描述'),
                maxLines: 3,
                maxLength: 1000,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      TagDraft(
        name: _nameController.text,
        slug: _slugController.text,
        description: _descriptionController.text,
      ),
    );
  }
}

/// 审计日志管理标签页
/// 展示系统操作日志，支持按操作类型和资源类型筛选
class _AuditLogAdminTab extends ConsumerStatefulWidget {
  const _AuditLogAdminTab();

  @override
  ConsumerState<_AuditLogAdminTab> createState() => _AuditLogAdminTabState();
}

/// 审计日志管理标签页状态管理
class _AuditLogAdminTabState extends ConsumerState<_AuditLogAdminTab> {
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
          (error, stackTrace) => _ErrorPane(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminAuditLogsProvider(_query)),
          ),
      data:
          (page) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SectionToolbar(
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
                const _EmptyPane(message: '暂无操作日志')
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
                  _formatDate(log.createdAt),
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

/// 内容状态标签组件
/// 根据状态显示不同颜色的标签
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ContentStatus status; // 内容状态

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      ContentStatus.published => scheme.primaryContainer,
      ContentStatus.archived => scheme.errorContainer,
      ContentStatus.draft => scheme.secondaryContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

/// 评论状态标签组件
class _CommentStatusChip extends StatelessWidget {
  const _CommentStatusChip({required this.status});

  final AdminCommentStatus status; // 评论状态

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      AdminCommentStatus.visible => scheme.primaryContainer,
      AdminCommentStatus.deleted => scheme.errorContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

/// 用户角色标签组件
class _UserRoleChip extends StatelessWidget {
  const _UserRoleChip({required this.role});

  final AdminUserRole role; // 用户角色

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (role) {
      AdminUserRole.admin => scheme.tertiaryContainer,
      AdminUserRole.user => scheme.secondaryContainer,
    };
    return Chip(label: Text(role.label), backgroundColor: color);
  }
}

/// 用户状态标签组件
class _UserStatusChip extends StatelessWidget {
  const _UserStatusChip({required this.status});

  final AdminUserStatus status; // 用户状态

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      AdminUserStatus.active => scheme.primaryContainer,
      AdminUserStatus.disabled => scheme.errorContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

/// 元数据文本组件
/// 显示图标 + 文本的元数据信息
class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon; // 图标
  final String text; // 文本

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(text)],
    );
  }
}

/// 媒体缩略图组件
/// 根据媒体类型显示缩略图或占位图标
class _MediaThumb extends StatelessWidget {
  const _MediaThumb({
    required this.url,
    required this.type,
    required this.size,
  });

  final String url; // 媒体 URL
  final MediaAssetType type; // 媒体类型
  final Size size; // 缩略图尺寸

  @override
  Widget build(BuildContext context) {
    final fallbackIcon = switch (type) {
      MediaAssetType.video => Icons.play_circle_outline,
      MediaAssetType.file => Icons.insert_drive_file_outlined,
      MediaAssetType.image => Icons.image_outlined,
    };
    final placeholder = SizedBox(
      width: size.width,
      height: size.height,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(fallbackIcon),
      ),
    );

    if (url.isEmpty || type != MediaAssetType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: placeholder,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size.width,
        height: size.height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

/// 内联错误组件
/// 在列表中显示错误信息的卡片
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message; // 错误信息

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

/// 错误面板组件
/// 居中显示错误信息和重试按钮
class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message; // 错误信息
  final VoidCallback onRetry; // 重试回调

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空面板组件
/// 数据为空时显示的提示信息
class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.message});

  final String message; // 提示信息

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(child: Text(message)),
    );
  }
}

/// 确认对话框
/// 通用的确认操作对话框，返回用户是否确认
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
  );
  return confirmed == true;
}

/// 显示 SnackBar 提示
void _showSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// 格式化日期
/// 时间戳为 0 时返回"未发布"，否则返回 yyyy-MM-dd HH:mm 格式
String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) {
    return '未发布';
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(date);
}

/// 格式化字节数
/// 自动转换为 B/KB/MB/GB 单位
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}

/// 解析可空整数
/// 空字符串返回 null，非空时尝试解析为 int
int? _parseNullableInt(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

/// 根据文件名推断媒体类型
/// 视频：mp4/webm/mov；图片：jpg/jpeg/png/gif/webp；其他：file
MediaAssetType _inferMediaType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mov')) {
    return MediaAssetType.video;
  }
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp')) {
    return MediaAssetType.image;
  }
  return MediaAssetType.file;
}
