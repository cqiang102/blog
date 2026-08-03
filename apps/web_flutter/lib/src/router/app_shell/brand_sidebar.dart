part of '../app_shell.dart';

class _BrandSidebar extends StatelessWidget {
  const _BrandSidebar({
    required this.expanded,
    required this.showText,
    required this.currentPath,
    required this.authenticated,
    required this.isAdmin,
    required this.avatarText,
    required this.onNavigate,
    required this.onToggleExpand,
    this.nickname,
    this.avatarUrl,
  });

  final bool expanded;
  final bool showText;
  final String currentPath;
  final bool authenticated;
  final bool isAdmin;
  final String? nickname;
  final String avatarText;
  final String? avatarUrl;
  final ValueChanged<_Destination> onNavigate;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accountItems = [
      if (authenticated) _destinations[4],
      if (isAdmin) _destinations[5],
      if (!authenticated) _destinations[6],
    ];

    return AnimatedContainer(
      duration: AppMotion.duration(context, const Duration(milliseconds: 280)),
      curve: Curves.easeInOutCubic,
      width: expanded ? 216 : 72,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.72),
              border: Border(
                right: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: showText ? AppSpacing.sm + 4 : AppSpacing.sm,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  children: [
                    _SidebarIdentity(
                      expanded: expanded,
                      showText: showText,
                      avatarExpanded: showText,
                      avatarText: avatarText,
                      avatarUrl: avatarUrl,
                      nickname: nickname,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    for (final item in _publicDestinations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _SidebarItem(
                          item: item,
                          expanded: expanded,
                          showText: showText,
                          selected: currentPath == item.path,
                          onTap: () => onNavigate(item),
                        ),
                      ),
                    const Spacer(),
                    Divider(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final item in accountItems) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: item == _destinations[6]
                            ? _SidebarCapsuleButton(
                                item: item,
                                expanded: expanded,
                                showText: showText,
                                onTap: () => onNavigate(item),
                              )
                            : _SidebarItem(
                                item: item,
                                expanded: expanded,
                                showText: showText,
                                selected: currentPath == item.path,
                                onTap: () => onNavigate(item),
                              ),
                      ),
                      // 管理按钮下方插入收起/展开按钮
                      if (isAdmin && item == _destinations[5])
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _SidebarExpandToggle(
                            expanded: expanded,
                            showText: showText,
                            onTap: onToggleExpand,
                          ),
                        ),
                    ],
                    // 非管理员时，收起/展开按钮放在最底部
                    if (!isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _SidebarExpandToggle(
                          expanded: expanded,
                          showText: showText,
                          onTap: onToggleExpand,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarIdentity extends StatelessWidget {
  const _SidebarIdentity({
    required this.expanded,
    required this.showText,
    required this.avatarExpanded,
    required this.avatarText,
    this.avatarUrl,
    this.nickname,
  });

  final bool expanded;
  final bool showText;
  final bool avatarExpanded;
  final String avatarText;
  final String? avatarUrl;
  final String? nickname;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasNetworkAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final avatarSize = avatarExpanded ? 64.0 : 40.0;
    final avatar = ClipOval(
      child: SizedBox(
        width: avatarSize,
        height: avatarSize,
        child: hasNetworkAvatar
            ? Image.network(
                resolveMediaUrl(avatarUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Image.asset('assets/images/lacia.webp', fit: BoxFit.cover),
              )
            : Image.asset('assets/images/lacia.webp', fit: BoxFit.cover),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        if (showText)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Text(
                '沐凉·日记',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                nickname?.isNotEmpty == true ? nickname! : '写代码，也记录生活',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ).animate().fade(begin: 0, duration: 200.ms, curve: Curves.easeOut),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.expanded,
    required this.showText,
    required this.selected,
    required this.onTap,
  });

  final _Destination item;
  final bool expanded;
  final bool showText;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 浅绿色选中效果
    final selectedBg = scheme.primary.withValues(alpha: 0.1);
    final selectedFg = scheme.primary;
    final foreground = selected ? selectedFg : scheme.onSurfaceVariant;

    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: showText ? 10 : 0),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: showText
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: HugeIcon(
                icon: selected ? item.selectedIcon : item.icon,
                size: 22,
                color: foreground,
              ),
            ),
            if (showText)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 10),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ).animate().fade(
                begin: 0,
                duration: 200.ms,
                curve: Curves.easeOut,
              ),
          ],
        ),
      ),
    );

    return expanded ? child : Tooltip(message: item.label, child: child);
  }
}

class _SidebarCapsuleButton extends StatelessWidget {
  const _SidebarCapsuleButton({
    required this.item,
    required this.expanded,
    required this.showText,
    required this.onTap,
  });

  final _Destination item;
  final bool expanded;
  final bool showText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final child = Material(
      color: scheme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: showText ? 12 : 0),
          child: Row(
            mainAxisAlignment: showText
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: HugeIcon(
                  icon: item.icon,
                  size: 22,
                  color: scheme.primary,
                ),
              ),
              if (showText)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 10),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ).animate().fade(
                  begin: 0,
                  duration: 200.ms,
                  curve: Curves.easeOut,
                ),
            ],
          ),
        ),
      ),
    );

    return expanded ? child : Tooltip(message: item.label, child: child);
  }
}

class _SidebarExpandToggle extends StatelessWidget {
  const _SidebarExpandToggle({
    required this.expanded,
    required this.showText,
    required this.onTap,
  });

  final bool expanded;
  final bool showText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = scheme.onSurfaceVariant;

    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: showText ? 10 : 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: showText
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: HugeIcon(
                icon: expanded
                    ? HugeIcons.strokeRoundedSidebarLeft01
                    : HugeIcons.strokeRoundedSidebarRight01,
                size: 22,
                color: foreground,
              ),
            ),
            if (showText)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 10),
                  Text(
                    '收起',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ).animate().fade(
                begin: 0,
                duration: 200.ms,
                curve: Curves.easeOut,
              ),
          ],
        ),
      ),
    );

    return expanded
        ? child
        : Tooltip(message: expanded ? '收起' : '展开', child: child);
  }
}
