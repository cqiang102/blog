// 个人中心模块
// 支持资料编辑、修改密码、查看评论/点赞/浏览活动记录、OAuth 账号绑定
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/oauth_state_storage.dart';
import '../../core/api_client.dart';
import '../../state/state.dart';
import '../../widgets/widgets.dart';
import '../../auth/auth_controller.dart';
import '../../core/constants.dart';
import '../../core/media_url.dart';
import '../../core/models.dart';
import '../../theme/app_spacing.dart';

/// 个人中心 Widget
/// 使用 TabBar 展示资料、评论、点赞、浏览四个标签页
/// 添加 AutomaticKeepAliveClientMixin 保持页面状态
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  static const _sections = [
    ('个人资料', '编辑头像、昵称与公开信息'),
    ('我的评论', '查看自己的评论记录'),
    ('我的点赞', '查看收藏和点赞过的内容'),
    ('浏览记录', '快速找回最近阅读的内容'),
  ];

  int _selectedIndex = 0;
  final Set<int> _visitedSections = {0};

  @override
  bool get wantKeepAlive => true;

  void _selectSection(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _visitedSections.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = ref.watch(authControllerProvider);

    return AppPageFrame(
      child: Column(
        children: [
          AppPageHeader(
            title: '个人中心',
            // subtitle: _sections[_selectedIndex].$2,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppThemeToggle(),
                IconButton(
                  tooltip: '退出登录',
                  onPressed: auth.isBusy
                      ? null
                      : () => ref.read(authControllerProvider).logout(),
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedLogout01),
                ),
              ],
            ),
          ),
          AppHorizontalTabs(
            labels: _sections.map((item) => item.$1).toList(),
            selectedIndex: _selectedIndex,
            onSelected: _selectSection,
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _visitedSections.contains(0)
                    ? const _ProfileForm()
                    : const SizedBox.shrink(),
                _visitedSections.contains(1)
                    ? const _RecordList(type: 'comments', label: '评论')
                    : const SizedBox.shrink(),
                _visitedSections.contains(2)
                    ? const _RecordList(type: 'likes', label: '点赞')
                    : const SizedBox.shrink(),
                _visitedSections.contains(3)
                    ? const _RecordList(type: 'views', label: '浏览')
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 个人资料表单组件
// ============================================================================

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm();

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _blogUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _seededUserId;
  bool _changingPassword = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;
  List<OAuthAccountInfo> _oauthAccounts = [];
  bool _loadingOAuth = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(authControllerProvider).user;
      if (user != null && _seededUserId == null) {
        _seed(user);
      }
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _blogUrlController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    if (user != null && _seededUserId != user.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _seed(user);
      });
    }

    final avatarUrl = _avatarUrl ?? user?.avatarUrl;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                _ProfileSectionCard(
                  title: '头像',
                  subtitle: '建议使用清晰、简洁的正方形图片',
                  child: _AvatarSection(
                    avatarUrl: avatarUrl,
                    uploading: _uploadingAvatar,
                    onUpload: _pickAndUploadAvatar,
                  ),
                ).fadeSlideIn(delay: 0.ms),
                const SizedBox(height: AppSpacing.md),
                _ProfileSectionCard(
                  title: '基本信息',
                  subtitle: '这些信息会展示在个人主页和互动记录中',
                  child: _buildBasicInfoForm(auth),
                ).fadeSlideIn(delay: 80.ms),
                const SizedBox(height: AppSpacing.md),
                _ProfileSectionCard(
                  title: user?.hasPassword == true ? '修改密码' : '设置密码',
                  subtitle: '定期更新密码有助于保护账号安全',
                  child: _buildPasswordSection(user),
                ).fadeSlideIn(delay: 160.ms),
                const SizedBox(height: AppSpacing.md),
                _ProfileSectionCard(
                  title: '账号绑定',
                  subtitle: '管理第三方登录方式',
                  child: _buildOAuthSection(context),
                ).fadeSlideIn(delay: 240.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建基本信息表单
  Widget _buildBasicInfoForm(AuthController auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nicknameController,
          decoration: const InputDecoration(labelText: '昵称'),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        TextField(
          controller: _bioController,
          decoration: const InputDecoration(labelText: '简介'),
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        TextField(
          controller: _blogUrlController,
          decoration: const InputDecoration(labelText: '博客地址'),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        TextField(
          controller: _emailController,
          readOnly: true,
          decoration: const InputDecoration(labelText: '邮箱（暂不支持修改）'),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: auth.isBusy ? null : _save,
            child: auth.isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存修改'),
          ),
        ),
      ],
    );
  }

  /// 构建密码区域
  Widget _buildPasswordSection(UserProfile? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user?.hasPassword == true) ...[
          TextField(
            controller: _oldPasswordController,
            decoration: const InputDecoration(labelText: '当前密码'),
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.sm + 4),
        ],
        TextField(
          controller: _newPasswordController,
          decoration: InputDecoration(
            labelText: user?.hasPassword == true ? '新密码' : '密码',
            hintText: '至少$kMinPasswordLength个字符',
          ),
          obscureText: true,
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        TextField(
          controller: _confirmPasswordController,
          decoration: const InputDecoration(labelText: '确认新密码'),
          obscureText: true,
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _changingPassword
                ? null
                : (user?.hasPassword == true ? _changePassword : _setPassword),
            child: _changingPassword
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(user?.hasPassword == true ? '修改密码' : '设置密码'),
          ),
        ),
      ],
    );
  }

  /// 构建 OAuth 绑定区域
  Widget _buildOAuthSection(BuildContext context) {
    final hasGithub = _oauthAccounts.any((a) => a.provider == 'GITHUB');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                title: const Text('GitHub'),
                subtitle: Text(
                  hasGithub
                      ? '已绑定: ${_oauthAccounts.firstWhere((a) => a.provider == 'GITHUB').providerUsername}'
                      : '未绑定',
                ),
                trailing: hasGithub
                    ? TextButton(
                        onPressed: () => _unbindOAuth('github'),
                        child: const Text('解绑'),
                      )
                    : TextButton(
                        onPressed: _bindGithub,
                        child: const Text('绑定'),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 填充用户数据到表单
  void _seed(UserProfile user) {
    _seededUserId = user.id;
    _nicknameController.text = user.nickname;
    _bioController.text = user.bio ?? '';
    _blogUrlController.text = user.blogUrl ?? '';
    _emailController.text = user.email;
    _avatarUrl = user.avatarUrl;
    _loadOAuthAccounts();
  }

  /// 加载 OAuth 账户绑定列表
  Future<void> _loadOAuthAccounts() async {
    if (_loadingOAuth) return;
    setState(() => _loadingOAuth = true);
    try {
      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) return;
      final accounts = await ref
          .read(apiClientProvider)
          .fetchOAuthAccounts(accessToken: token);
      if (mounted) {
        setState(() => _oauthAccounts = accounts);
      }
    } catch (_) {
      // OAuth 绑定信息不影响个人资料主体展示。
    } finally {
      if (mounted) setState(() => _loadingOAuth = false);
    }
  }

  /// 绑定 GitHub 账号
  Future<void> _bindGithub() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;
    try {
      final githubUrl = await ref
          .read(apiClientProvider)
          .fetchGithubBindUrl(token);
      final uri = Uri.parse(githubUrl);
      final state = uri.queryParameters['state'];
      if (state == null || state.isEmpty) {
        throw const ApiException('GitHub 绑定状态初始化失败');
      }
      storeOAuthState(state);
      final launched = await launchUrl(uri, webOnlyWindowName: '_self');
      if (!launched) {
        clearOAuthState();
        throw const ApiException('无法打开 GitHub 绑定页面');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('获取绑定地址失败: $e')));
      }
    }
  }

  /// 解绑 OAuth 账号
  Future<void> _unbindOAuth(String provider) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认解绑'),
        content: Text('确定要解绑 ${provider.toUpperCase()} 账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) return;
      await ref
          .read(apiClientProvider)
          .unbindOAuthAccount(accessToken: token, provider: provider);
      _loadOAuthAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已解绑')));
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    }
  }

  /// 选择并上传头像
  Future<void> _pickAndUploadAvatar() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _uploadingAvatar = true);

      final token = await ref
          .read(authControllerProvider)
          .getValidAccessToken();
      if (token == null) {
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        context.go('/login?from=/profile');
        return;
      }

      final newAvatarUrl = await ref
          .read(apiClientProvider)
          .uploadAvatar(
            accessToken: token,
            bytes: file.bytes!,
            filename: file.name,
          );

      if (mounted) {
        setState(() {
          _avatarUrl = newAvatarUrl;
          _uploadingAvatar = false;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('头像已更新')));
    } on ApiException catch (error) {
      if (mounted) setState(() => _uploadingAvatar = false);
      if (!mounted) return;
      _showError(error.message);
    } catch (error) {
      if (mounted) setState(() => _uploadingAvatar = false);
      if (!mounted) return;
      _showError(error.toString());
    }
  }

  /// 保存个人资料
  Future<void> _save() async {
    try {
      await ref
          .read(authControllerProvider)
          .updateProfile(
            email: _emailController.text.trim(),
            nickname: _nicknameController.text.trim(),
            bio: _bioController.text.trim(),
            blogUrl: _blogUrlController.text.trim(),
            avatarUrl: _avatarUrl,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存')));
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    }
  }

  /// 修改密码
  Future<void> _changePassword() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (oldPassword.isEmpty) {
      _showError('请输入当前密码');
      return;
    }
    if (newPassword.length < kMinPasswordLength) {
      _showError('新密码至少$kMinPasswordLength个字符');
      return;
    }
    if (newPassword != confirmPassword) {
      _showError('两次输入的密码不一致');
      return;
    }

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    if (mounted) setState(() => _changingPassword = true);
    try {
      await ref
          .read(apiClientProvider)
          .changePassword(
            accessToken: token,
            oldPassword: oldPassword,
            newPassword: newPassword,
          );
      if (!mounted) return;
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码已修改')));
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  /// 设置密码
  Future<void> _setPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < kMinPasswordLength) {
      _showError('新密码至少$kMinPasswordLength个字符');
      return;
    }
    if (newPassword != confirmPassword) {
      _showError('两次输入的密码不一致');
      return;
    }

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    if (mounted) setState(() => _changingPassword = true);
    try {
      await ref
          .read(apiClientProvider)
          .setPassword(accessToken: token, newPassword: newPassword);
      if (!mounted) return;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      await ref.read(authControllerProvider).loadUser();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码已设置')));
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

// ============================================================================
// 头像区域组件
// ============================================================================

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.avatarUrl,
    required this.uploading,
    required this.onUpload,
  });

  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(resolveMediaUrl(avatarUrl!))
                    : null,
                child: avatarUrl == null
                    ? const HugeIcon(
                        icon: HugeIcons.strokeRoundedUser,
                        size: 44,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: uploading ? null : onUpload,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: uploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const HugeIcon(
                              icon: HugeIcons.strokeRoundedCamera01,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: uploading ? null : onUpload,
            child: const Text('更换头像'),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 活动记录列表组件
// ============================================================================

class _RecordList extends ConsumerStatefulWidget {
  const _RecordList({required this.type, required this.label});

  final String type;
  final String label;

  @override
  ConsumerState<_RecordList> createState() => _RecordListState();
}

class _RecordListState extends ConsumerState<_RecordList>
    with PaginationMixin<_RecordList, UserActivity> {
  @override
  int get pageSize => 20;

  @override
  Future<PageResult<UserActivity>> fetchPage(int page, int size) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      throw Exception('请先登录');
    }
    return await ref
        .read(apiClientProvider)
        .fetchMyActivity(
          accessToken: token,
          type: widget.type,
          page: page,
          size: size,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && items.isEmpty) {
      return buildErrorPanel();
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          '暂无${widget.label}记录',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: items.length + (hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return buildLoadingIndicator();
        }
        final item = items[index];
        final date = DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt);
        return Card(
          key: ValueKey(item.id),
          child: ListTile(
            title: Text(item.title),
            subtitle: Text(date),
            onTap: () => context.go('/contents/${item.contentId}'),
            trailing: IconButton(
              tooltip: '删除',
              onPressed: () => _delete(item),
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete01),
            ),
          ),
        );
      },
    );
  }

  /// 删除活动记录
  Future<void> _delete(UserActivity item) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteMyActivity(accessToken: token, type: widget.type, id: item.id);
      if (!mounted) return;
      setState(() {
        items.remove(item);
        total--;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
