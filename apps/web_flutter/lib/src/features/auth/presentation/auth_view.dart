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
import '../../../router/internal_redirect.dart';
import '../application/auth_flow_controller.dart';

part 'auth_brand.dart';
part 'auth_form.dart';

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
            final form = KeyedSubtree(
              key: const ValueKey('auth-form'),
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
                    .read(authFlowControllerProvider.notifier)
                    .setRememberMe,
                onTogglePassword: ref
                    .read(authFlowControllerProvider.notifier)
                    .togglePasswordVisibility,
                onSendCode: _sendCode,
                onSubmit: _submit,
                onGithubLogin: _openGithubLogin,
              ).fadeSlideIn(delay: 200.ms),
            );
            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (MediaQuery.sizeOf(context).height - 48).clamp(
                  560,
                  double.infinity,
                ),
              ),
              child: Center(
                child: Container(
                  key: const ValueKey('auth-card'),
                  constraints: const BoxConstraints(maxWidth: 1000),
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
                      ? AnimatedContainer(
                          duration: AppMotion.duration(
                            context,
                            AppAnimations.normal,
                          ),
                          curve: AppAnimations.slideCurve,
                          // BoxDecoration 的 1px 描边会计入外尺寸。
                          height: flow.isRegister ? 678 : 598,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(
                                flex: 13,
                                child: _AuthBrandPanel(),
                              ),
                              Expanded(
                                flex: 12,
                                child: LayoutBuilder(
                                  builder: (context, panelConstraints) {
                                    final minContentHeight =
                                        panelConstraints.maxHeight > 64
                                        ? panelConstraints.maxHeight - 64
                                        : 0.0;
                                    return SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 40,
                                        vertical: AppSpacing.xl,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: minContentHeight,
                                        ),
                                        child: Center(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 400,
                                            ),
                                            child: form,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
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
                            Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: form,
                              ),
                            ),
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
      context.go(safeInternalRedirect(from));
    }
  }

  Future<void> _openGithubLogin() async {
    await ref.read(authFlowControllerProvider.notifier).openGithubLogin();
  }
}
