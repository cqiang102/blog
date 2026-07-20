part of 'auth_view.dart';

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
            const SizedBox(height: AppSpacing.md + 4),
            _AuthModeSwitch(
              register: register,
              busy: busy,
              onChanged: onModeChanged,
            ),
            const SizedBox(height: AppSpacing.md + 4),
            if (formError != null) ...[
              _FormError(message: formError!),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              key: const ValueKey('auth-email-field'),
              controller: emailController,
              style: Theme.of(context).textTheme.bodyMedium,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: _authFieldDecoration(context, label: '邮箱'),
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
                key: const ValueKey('auth-nickname-field'),
                controller: nicknameController,
                style: Theme.of(context).textTheme.bodyMedium,
                autofillHints: const [AutofillHints.nickname],
                decoration: _authFieldDecoration(context, label: '昵称（可选）'),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('auth-code-field'),
                      controller: codeController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      keyboardType: TextInputType.number,
                      decoration: _authFieldDecoration(context, label: '邮箱验证码'),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) return '请输入验证码';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  SizedBox(
                    height: 52,
                    child: FilledButton.tonal(
                      onPressed: countdown > 0 ? null : onSendCode,
                      child: Text(countdown > 0 ? '${countdown}s' : '获取验证码'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm + 4),
            TextFormField(
              key: const ValueKey('auth-password-field'),
              controller: passwordController,
              style: Theme.of(context).textTheme.bodyMedium,
              obscureText: obscurePassword,
              autofillHints: [
                register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: _authFieldDecoration(
                context,
                label: '密码',
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

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({
    required this.register,
    required this.busy,
    required this.onChanged,
  });

  final bool register;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('auth-mode-switch'),
      height: 48,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _AuthModeOption(
            label: '登录',
            selected: !register,
            onTap: busy ? null : () => onChanged(false),
          ),
          _AuthModeOption(
            label: '注册',
            selected: register,
            onTap: busy ? null : () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _AuthModeOption extends StatelessWidget {
  const _AuthModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppAnimations.fast),
          curve: AppAnimations.slideCurve,
          decoration: BoxDecoration(
            color: selected
                ? scheme.surfaceContainerLowest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _authFieldDecoration(
  BuildContext context, {
  required String label,
  Widget? suffixIcon,
}) {
  final scheme = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(12);
  final border = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    isDense: true,
    filled: true,
    fillColor: scheme.surfaceContainer,
    constraints: const BoxConstraints(minHeight: 52),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 12,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.error, width: 1.5),
    ),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
  );
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
