// 个人中心模块
// 支持资料编辑、修改密码、查看评论/点赞/浏览活动记录、OAuth 账号绑定
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_providers.dart';
import '../../core/models.dart';

/// 个人中心 Widget
/// 使用 TabBar 展示资料、评论、点赞、浏览四个标签页
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider); // 获取认证状态

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('个人中心'),
          actions: [
            IconButton(
              tooltip: '退出登录',
              onPressed:
                  auth.isBusy
                      ? null
                      : () => ref.read(authControllerProvider).logout(),
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: '资料'),
              Tab(icon: Icon(Icons.comment), text: '评论'),
              Tab(icon: Icon(Icons.favorite), text: '点赞'),
              Tab(icon: Icon(Icons.history), text: '浏览'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProfileForm(),
            _RecordList(type: 'comments', label: '评论'),
            _RecordList(type: 'likes', label: '点赞'),
            _RecordList(type: 'views', label: '浏览'),
          ],
        ),
      ),
    );
  }
}

/// 个人资料表单组件
/// 编辑用户昵称、简介、博客地址、头像上传、邮箱，以及修改密码
class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm();

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

/// 个人资料表单状态管理
/// 管理表单控制器、数据填充和提交逻辑
class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _nicknameController = TextEditingController(); // 昵称输入框
  final _bioController = TextEditingController(); // 简介输入框
  final _blogUrlController = TextEditingController(); // 博客地址输入框
  final _emailController = TextEditingController(); // 邮箱输入框
  final _oldPasswordController = TextEditingController(); // 当前密码输入框
  final _newPasswordController = TextEditingController(); // 新密码输入框
  final _confirmPasswordController = TextEditingController(); // 确认新密码输入框
  String? _seededUserId; // 已填充数据的用户 ID（防止重复填充）
  bool _changingPassword = false; // 是否正在修改密码
  bool _uploadingAvatar = false; // 是否正在上传头像
  String? _avatarUrl; // 当前头像 URL（本地状态，上传后立即更新）
  List<OAuthAccountInfo> _oauthAccounts = []; // 已绑定的 OAuth 账户
  bool _loadingOAuth = false; // 是否正在加载 OAuth 账户

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
      _seed(user);
    }

    // 使用本地头像 URL 或用户头像 URL
    final avatarUrl = _avatarUrl ?? user?.avatarUrl;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 头像显示和上传按钮
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 44)
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
                    onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _uploadingAvatar
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _uploadingAvatar ? null : _pickAndUploadAvatar,
            child: const Text('更换头像'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nicknameController,
          decoration: const InputDecoration(labelText: '昵称'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bioController,
          decoration: const InputDecoration(labelText: '简介'),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _blogUrlController,
          decoration: const InputDecoration(labelText: '博客地址'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: '邮箱'),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: auth.isBusy ? null : _save,
            icon:
                auth.isBusy
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save),
            label: const Text('保存'),
          ),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          user?.hasPassword == true ? '修改密码' : '设置密码',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        if (user?.hasPassword == true) ...[
          // 已设置密码：显示修改密码表单
          TextField(
            controller: _oldPasswordController,
            decoration: const InputDecoration(labelText: '当前密码'),
            obscureText: true,
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _newPasswordController,
          decoration: InputDecoration(
            labelText: user?.hasPassword == true ? '新密码' : '密码',
            hintText: '至少6个字符',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordController,
          decoration: const InputDecoration(labelText: '确认新密码'),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _changingPassword
                ? null
                : (user?.hasPassword == true ? _changePassword : _setPassword),
            icon:
                _changingPassword
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.lock_outline),
            label: Text(user?.hasPassword == true ? '修改密码' : '设置密码'),
          ),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        // 账号绑定区域
        Text(
          '账号绑定',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildOAuthSection(context),
      ],
    );
  }

  /// 填充用户数据到表单
  /// 将用户资料填充到各输入框，仅首次调用生效
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
      final accounts = await ref.read(apiClientProvider).fetchOAuthAccounts(
        accessToken: token,
      );
      if (mounted) {
        setState(() {
          _oauthAccounts = accounts;
          _loadingOAuth = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOAuth = false);
    }
  }

  /// 构建 OAuth 账号绑定区域
  Widget _buildOAuthSection(BuildContext context) {
    final hasGithub = _oauthAccounts.any((a) => a.provider == 'GITHUB');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.code),
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
    );
  }

  /// 绑定 GitHub 账号
  Future<void> _bindGithub() async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;
    try {
      final githubUrl = await ref.read(apiClientProvider).fetchGithubBindUrl(token);
      await launchUrl(Uri.parse(githubUrl), webOnlyWindowName: '_self');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取绑定地址失败: $e')),
        );
      }
    }
  }

  /// 解绑 OAuth 账号
  Future<void> _unbindOAuth(String provider) async {
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
      await ref.read(apiClientProvider).unbindOAuthAccount(
        accessToken: token,
        provider: provider,
      );
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
  /// 使用文件选择器选择图片，上传到服务器后更新头像 URL
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

      final token = await ref.read(authControllerProvider).getValidAccessToken();
      if (token == null) {
        if (!mounted) return;
        context.go('/login?from=/profile');
        return;
      }

      final newAvatarUrl = await ref.read(apiClientProvider).uploadAvatar(
        accessToken: token,
        bytes: file.bytes!,
        filename: file.name,
      );

      setState(() {
        _avatarUrl = newAvatarUrl;
        _uploadingAvatar = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('头像已更新')),
      );
    } on ApiException catch (error) {
      setState(() => _uploadingAvatar = false);
      if (!mounted) return;
      _showError(error.message);
    } catch (error) {
      setState(() => _uploadingAvatar = false);
      if (!mounted) return;
      _showError(error.toString());
    }
  }

  /// 保存个人资料
  /// 收集表单数据调用 API 更新用户资料
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
  /// 校验输入后调用 API 修改密码，成功后清空密码框
  Future<void> _changePassword() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (oldPassword.isEmpty) {
      _showError('请输入当前密码');
      return;
    }
    if (newPassword.length < 6) {
      _showError('新密码至少6个字符');
      return;
    }
    if (newPassword != confirmPassword) {
      _showError('两次输入的密码不一致');
      return;
    }

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    setState(() => _changingPassword = true);
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

  /// 设置密码（用于 OAuth 用户首次设置密码）
  /// 校验输入后调用 API 设置密码，成功后清空密码框并刷新用户信息
  Future<void> _setPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 6) {
      _showError('新密码至少6个字符');
      return;
    }
    if (newPassword != confirmPassword) {
      _showError('两次输入的密码不一致');
      return;
    }

    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    setState(() => _changingPassword = true);
    try {
      await ref
          .read(apiClientProvider)
          .setPassword(
            accessToken: token,
            newPassword: newPassword,
          );
      if (!mounted) return;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      // 刷新用户信息以更新 hasPassword 状态
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

/// 活动记录列表组件
/// 展示用户的评论/点赞/浏览记录，支持无限滚动分页和删除
class _RecordList extends ConsumerStatefulWidget {
  const _RecordList({required this.type, required this.label});

  final String type; // 记录类型：comments/likes/views
  final String label; // 显示标签

  @override
  ConsumerState<_RecordList> createState() => _RecordListState();
}

/// 活动记录列表状态管理
/// 管理分页加载、滚动监听和删除操作
class _RecordListState extends ConsumerState<_RecordList> {
  final _scrollController = ScrollController(); // 滚动控制器
  final List<UserActivity> _items = []; // 已加载的记录列表
  int _currentPage = 0; // 当前页码
  int _total = 0; // 总记录数
  bool _isLoading = false; // 是否正在加载
  bool _hasMore = true; // 是否还有更多数据
  String? _error; // 错误信息

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听回调
  /// 滚动到底部附近时触发加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  /// 加载更多记录
  /// 使用当前类型和页码请求 API，追加数据到列表
  Future<void> _loadMore() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = ref.read(authControllerProvider).accessToken;
      if (token == null) {
        setState(() {
          _error = '请先登录';
          _isLoading = false;
        });
        return;
      }

      final result = await ref.read(apiClientProvider).fetchMyActivity(
            accessToken: token,
            type: widget.type,
            page: _currentPage,
            size: 20,
          );
      setState(() {
        _items.addAll(result.items);
        _total = result.total;
        _currentPage++;
        _hasMore = _items.length < _total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 重置列表并重新加载
  void _resetAndLoad() {
    setState(() {
      _items.clear();
      _currentPage = 0;
      _total = 0;
      _hasMore = true;
      _error = null;
    });
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _resetAndLoad,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(child: Text('暂无${widget.label}记录'));
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = _items[index];
        final date = DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(item.title),
            subtitle: Text(date),
            onTap: () => context.go('/contents/${item.contentId}'),
            trailing: IconButton(
              tooltip: '删除',
              onPressed: () => _delete(item),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        );
      },
    );
  }

  /// 删除活动记录
  /// 调用 API 删除指定记录，成功后从列表中移除
  Future<void> _delete(UserActivity item) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteMyActivity(accessToken: token, type: widget.type, id: item.id);
      setState(() {
        _items.remove(item);
        _total--;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
