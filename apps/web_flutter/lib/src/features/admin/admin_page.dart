import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';
import '../../core/models.dart';

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final role = auth.user?.role.toUpperCase();

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
      length: 4,
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
            tabs: [
              Tab(icon: Icon(Icons.space_dashboard_outlined), text: '概览'),
              Tab(icon: Icon(Icons.article_outlined), text: '内容'),
              Tab(icon: Icon(Icons.perm_media_outlined), text: '媒体'),
              Tab(icon: Icon(Icons.sell_outlined), text: '标签'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DashboardTab(),
            _ContentAdminTab(),
            _MediaAdminTab(),
            _TagAdminTab(),
          ],
        ),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(adminMediaProvider);
    ref.invalidate(adminTagsProvider);
  }
}

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

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<AdminMetric> metrics;

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

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid();

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

class _ContentAdminRow extends StatelessWidget {
  const _ContentAdminRow({
    required this.content,
    required this.onEdit,
    required this.onArchive,
  });

  final AdminContentItem content;
  final VoidCallback onEdit;
  final VoidCallback? onArchive;

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
                actionLabel: '新增媒体',
                actionIcon: Icons.add,
                onAction: () => _openMediaEditor(context, ref, contents),
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

  void _refreshMediaState(WidgetRef ref) {
    ref.invalidate(adminMediaProvider);
    ref.invalidate(adminContentsProvider);
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(recommendationsProvider);
  }
}

class _MediaAdminRow extends StatelessWidget {
  const _MediaAdminRow({
    required this.media,
    required this.onEdit,
    required this.onSetCover,
    required this.onDelete,
  });

  final AdminMediaItem media;
  final VoidCallback onEdit;
  final VoidCallback? onSetCover;
  final VoidCallback onDelete;

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

class _SectionToolbar extends StatelessWidget {
  const _SectionToolbar({
    required this.title,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

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
        FilledButton.icon(
          onPressed: onAction,
          icon: Icon(actionIcon),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _ContentEditorDialog extends StatefulWidget {
  const _ContentEditorDialog({required this.content, required this.tags});

  final AdminContentItem? content;
  final List<TagItem> tags;

  @override
  State<_ContentEditorDialog> createState() => _ContentEditorDialogState();
}

class _ContentEditorDialogState extends State<_ContentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _summaryController = TextEditingController();
  final _bodyController = TextEditingController();
  late ContentType _type;
  late ContentStatus _status;
  late bool _pinned;
  late Set<String> _tagSlugs;

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

class _MediaEditorDialog extends StatefulWidget {
  const _MediaEditorDialog({required this.media, required this.contents});

  final AdminMediaItem? media;
  final List<AdminContentItem> contents;

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

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

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

class _TagEditorDialog extends StatefulWidget {
  const _TagEditorDialog({required this.tag});

  final TagItem? tag;

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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ContentStatus status;

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

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(text)],
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({
    required this.url,
    required this.type,
    required this.size,
  });

  final String url;
  final MediaAssetType type;
  final Size size;

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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

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

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(child: Text(message)),
    );
  }
}

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

void _showSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) {
    return '未发布';
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(date);
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}

int? _parseNullableInt(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}
