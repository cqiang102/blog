part of 'profile_view.dart';

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
