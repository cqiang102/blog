part of 'profile_view.dart';

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
    final formState = ref.watch(profileFormControllerProvider);
    final user = auth.user;

    if (user != null && _seededUserId != user.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _seed(user);
      });
    }

    final avatarUrl = formState.avatarUrl ?? user?.avatarUrl;

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
                    uploading: formState.isUploadingAvatar,
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
                  child: _buildPasswordSection(user, formState),
                ).fadeSlideIn(delay: 160.ms),
                const SizedBox(height: AppSpacing.md),
                _ProfileSectionCard(
                  title: '账号绑定',
                  subtitle: '管理第三方登录方式',
                  child: _buildOAuthSection(formState),
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
  Widget _buildPasswordSection(UserProfile? user, ProfileFormState formState) {
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
            onPressed: formState.isChangingPassword
                ? null
                : () => _updatePassword(user?.hasPassword == true),
            child: formState.isChangingPassword
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
  Widget _buildOAuthSection(ProfileFormState formState) {
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
                  formState.hasGithub
                      ? '已绑定: ${formState.oauthAccounts.firstWhere((a) => a.provider == 'GITHUB').providerUsername}'
                      : '未绑定',
                ),
                trailing: formState.hasGithub
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
    final controller = ref.read(profileFormControllerProvider.notifier);
    controller.seedAvatar(user.avatarUrl);
    controller.loadOAuthAccounts();
  }

  /// 绑定 GitHub 账号
  Future<void> _bindGithub() async {
    final error = await ref
        .read(profileFormControllerProvider.notifier)
        .bindGithub();
    if (mounted && error != null) _showError(error);
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

    final error = await ref
        .read(profileFormControllerProvider.notifier)
        .unbindOAuth(provider);
    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已解绑')));
    } else {
      _showError(error);
    }
  }

  /// 选择并上传头像
  Future<void> _pickAndUploadAvatar() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.bytes == null) return;

    final result = await ref
        .read(profileFormControllerProvider.notifier)
        .uploadAvatar(bytes: file.bytes!, filename: file.name);
    if (!mounted) return;
    _handleResult(result);
  }

  /// 保存个人资料
  Future<void> _save() async {
    final result = await ref
        .read(profileFormControllerProvider.notifier)
        .saveProfile(
          email: _emailController.text,
          nickname: _nicknameController.text,
          bio: _bioController.text,
          blogUrl: _blogUrlController.text,
        );
    if (mounted) _handleResult(result);
  }

  Future<void> _updatePassword(bool hasPassword) async {
    final result = await ref
        .read(profileFormControllerProvider.notifier)
        .updatePassword(
          hasPassword: hasPassword,
          oldPassword: _oldPasswordController.text,
          newPassword: _newPasswordController.text,
          confirmPassword: _confirmPasswordController.text,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    }
    _handleResult(result);
  }

  void _handleResult(ProfileActionResult result) {
    if (result.loginRequired) {
      context.go('/login?from=/profile');
    } else if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } else {
      _showError(result.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
