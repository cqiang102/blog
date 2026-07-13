import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../state/state.dart';
import '../../../widgets/widgets.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_motion.dart';
import '../application/auth_flow_controller.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final email = await ref
          .read(authFlowControllerProvider.notifier)
          .loadSavedEmail();
      if (mounted && email != null) _emailController.text = email;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _switchMode(bool register) {
    ref.read(authFlowControllerProvider.notifier).switchMode(register);
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final flow = ref.watch(authFlowControllerProvider);

    return AppPageFrame(
      maxWidth: 1180,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (MediaQuery.sizeOf(context).height - 48).clamp(
                  560,
                  double.infinity,
                ),
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  decoration: wide
                      ? BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        )
                      : null,
                  clipBehavior: wide ? Clip.antiAlias : Clip.none,
                  child: wide
                      ? SizedBox(
                          height: 640,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(flex: 5, child: _AuthBrandPanel()),
                              Expanded(
                                flex: 5,
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.xl),
                                  child: _AuthForm(
                                    formKey: _formKey,
                                    register: flow.isRegister,
                                    rememberMe: flow.rememberMe,
                                    obscurePassword: flow.obscurePassword,
                                    countdown: flow.countdown,
                                    formError: flow.formError,
                                    busy: auth.isBusy,
                                    emailController: _emailController,
                                    passwordController: _passwordController,
                                    nicknameController: _nicknameController,
                                    codeController: _codeController,
                                    onModeChanged: _switchMode,
                                    onRememberChanged: ref
                                        .read(
                                          authFlowControllerProvider.notifier,
                                        )
                                        .setRememberMe,
                                    onTogglePassword: ref
                                        .read(
                                          authFlowControllerProvider.notifier,
                                        )
                                        .togglePasswordVisibility,
                                    onSendCode: _sendCode,
                                    onSubmit: _submit,
                                    onGithubLogin: _openGithubLogin,
                                  ).fadeSlideIn(delay: 200.ms),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _MobileAuthBrand(),
                            const SizedBox(height: AppSpacing.xl),
                            _AuthForm(
                              formKey: _formKey,
                              register: flow.isRegister,
                              rememberMe: flow.rememberMe,
                              obscurePassword: flow.obscurePassword,
                              countdown: flow.countdown,
                              formError: flow.formError,
                              busy: auth.isBusy,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              nicknameController: _nicknameController,
                              codeController: _codeController,
                              onModeChanged: _switchMode,
                              onRememberChanged: ref
                                  .read(authFlowControllerProvider.notifier)
                                  .setRememberMe,
                              onTogglePassword: ref
                                  .read(authFlowControllerProvider.notifier)
                                  .togglePasswordVisibility,
                              onSendCode: _sendCode,
                              onSubmit: _submit,
                              onGithubLogin: _openGithubLogin,
                            ).fadeSlideIn(delay: 200.ms),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _sendCode() async {
    final sent = await ref
        .read(authFlowControllerProvider.notifier)
        .sendCode(_emailController.text);
    if (sent && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码已发送，请检查邮箱')));
    }
  }

  Future<void> _submit() async {
    ref.read(authFlowControllerProvider.notifier).clearError();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final succeeded = await ref
        .read(authFlowControllerProvider.notifier)
        .submit(
          email: email,
          password: _passwordController.text,
          nickname: _nicknameController.text.trim(),
          code: _codeController.text.trim(),
        );
    if (succeeded && mounted) {
      final from = GoRouterState.of(context).uri.queryParameters['from'];
      context.go(from == null || from.isEmpty ? '/profile' : from);
    }
  }

  Future<void> _openGithubLogin() async {
    await ref.read(authFlowControllerProvider.notifier).openGithubLogin();
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heroStyle = Theme.of(
      context,
    ).textTheme.displaySmall?.copyWith(color: scheme.onPrimaryContainer);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage('assets/images/lacia.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Text('沐凉·日记', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              const AppThemeToggle(),
            ],
          ),
          const Spacer(),
          AppMotion.reduce(context)
              ? Text('欢迎回来，\n继续写下新的故事。', style: heroStyle)
              : AnimatedTextKit(
                  isRepeatingAnimation: false,
                  totalRepeatCount: 1,
                  animatedTexts: [
                    TypewriterAnimatedText(
                      '欢迎回来，\n继续写下新的故事。',
                      speed: const Duration(milliseconds: 80),
                      textStyle: heroStyle,
                      cursor: '|',
                    ),
                  ],
                ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '登录后可以参与评论、收藏喜欢的内容，并与博客 AI 助手继续对话。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _BrandFeature(label: '参与文章讨论').fadeSlideIn(delay: 400.ms),
          const SizedBox(height: AppSpacing.sm + 4),
          const _BrandFeature(label: '保存你的阅读足迹').fadeSlideIn(delay: 500.ms),
          const SizedBox(height: AppSpacing.sm + 4),
          const _BrandFeature(
            label: '使用个人知识库 AI 助手',
          ).fadeSlideIn(delay: 600.ms),
          const Spacer(),
          Text(
            '写代码，也记录生活。',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandFeature extends StatelessWidget {
  const _BrandFeature({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _MobileAuthBrand extends StatelessWidget {
  const _MobileAuthBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '沐凉·日记',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const AppThemeToggle(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '登录后继续阅读、交流与探索。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.formKey,
    required this.register,
    required this.rememberMe,
    required this.obscurePassword,
    required this.countdown,
    required this.busy,
    required this.emailController,
    required this.passwordController,
    required this.nicknameController,
    required this.codeController,
    required this.onModeChanged,
    required this.onRememberChanged,
    required this.onTogglePassword,
    required this.onSendCode,
    required this.onSubmit,
    required this.onGithubLogin,
    this.formError,
  });

  final GlobalKey<FormState> formKey;
  final bool register;
  final bool rememberMe;
  final bool obscurePassword;
  final int countdown;
  final bool busy;
  final String? formError;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController nicknameController;
  final TextEditingController codeController;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSendCode;
  final VoidCallback onSubmit;
  final VoidCallback onGithubLogin;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              register ? '创建账号' : '欢迎回来',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              register ? '注册后即可参与互动和使用 AI 助手。' : '使用邮箱或 GitHub 登录你的账号。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('登录')),
                ButtonSegment(value: true, label: Text('注册')),
              ],
              selected: {register},
              onSelectionChanged: busy
                  ? null
                  : (selection) => onModeChanged(selection.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (formError != null) ...[
              _FormError(message: formError!),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: '邮箱',
                prefixIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedMail01,
                  size: 20,
                ),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return '请输入邮箱';
                if (!email.contains('@')) return '请输入有效的邮箱地址';
                return null;
              },
            ),
            if (register) ...[
              const SizedBox(height: AppSpacing.sm + 4),
              TextFormField(
                controller: nicknameController,
                autofillHints: const [AutofillHints.nickname],
                decoration: const InputDecoration(
                  labelText: '昵称（可选）',
                  prefixIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedUser,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '邮箱验证码',
                        prefixIcon: HugeIcon(
                          icon: HugeIcons.strokeRoundedTick01,
                          size: 20,
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) return '请输入验证码';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  FilledButton.tonal(
                    onPressed: countdown > 0 ? null : onSendCode,
                    child: Text(countdown > 0 ? '${countdown}s' : '获取验证码'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm + 4),
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              autofillHints: [
                register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedLock,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  tooltip: obscurePassword ? '显示密码' : '隐藏密码',
                  onPressed: onTogglePassword,
                  icon: HugeIcon(
                    icon: obscurePassword
                        ? HugeIcons.strokeRoundedView
                        : HugeIcons.strokeRoundedViewOff,
                    size: 20,
                  ),
                ),
              ),
              validator: (value) {
                final password = value ?? '';
                if (password.isEmpty) return '请输入密码';
                if (register && password.length < 8) return '密码至少需要 8 个字符';
                return null;
              },
              onFieldSubmitted: (_) => onSubmit(),
            ),
            if (!register) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Checkbox(
                    value: rememberMe,
                    onChanged: (value) => onRememberChanged(value ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => onRememberChanged(!rememberMe),
                    child: Text(
                      '记住邮箱',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: busy ? null : onSubmit,
              child: AnimatedSwitcher(
                duration: AppMotion.duration(context, AppAnimations.fast),
                child: busy
                    ? const SizedBox.square(
                        key: ValueKey('loading'),
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        key: ValueKey(register),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Text(register ? '注册并登录' : '登录')],
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    '或',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: busy ? null : onGithubLogin,
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedCode),
              label: const Text('使用 GitHub 登录'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert01,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
