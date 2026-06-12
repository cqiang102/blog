// 响应式 Shell 布局组件
// 包含 BlogShell、Sidebar 和导航目的地配置

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../state/state.dart';
import '../core/constants.dart';
import '../core/media_url.dart';
import '../theme/app_spacing.dart';

/// 响应式 Shell 布局组件
/// 使用 StatefulNavigationShell 保持页面状态，避免切换标签时销毁重建
class BlogShell extends ConsumerStatefulWidget {
  const BlogShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<BlogShell> createState() => _BlogShellState();
}

class _BlogShellState extends ConsumerState<BlogShell> {
  bool? _sidebarExpandedOverride;
  bool _sidebarShowText = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prewarmPublicData().catchError((_) {}));
    });
  }

  Future<void> _prewarmPublicData() async {
    final query = ref.read(contentFilterProvider).toQuery();
    final pagination = ref.read(contentPaginationProvider(query));
    if (pagination.items.isEmpty &&
        !pagination.isLoading &&
        pagination.error == null) {
      unawaited(
        ref.read(contentPaginationProvider(query).notifier).resetAndLoad(),
      );
    }

    await Future.wait<Object?>([
      ref.read(recommendationsProvider.future),
      ref.read(friendsProvider.future),
      ref.read(tagsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final nickname = auth.user?.nickname.trim();
    final avatarText =
        nickname == null || nickname.isEmpty ? 'C' : nickname.characters.first;
    final currentPath = _destinations[widget.navigationShell.currentIndex].path;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kWideBreakpoint;

        if (wide) {
          final autoExpanded = constraints.maxWidth >= kDesktopBreakpoint;
          final expanded = _sidebarExpandedOverride ?? autoExpanded;
          final showText = expanded ? _sidebarShowText : false;
          return Scaffold(
            body: CustomPaint(
              painter: _GridPatternPainter(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
              ),
              size: Size.infinite,
              child: Row(
                children: [
                  _BrandSidebar(
                    expanded: expanded,
                    showText: showText,
                    currentPath: currentPath,
                    authenticated: auth.isAuthenticated,
                    isAdmin: auth.user?.isAdmin ?? false,
                    nickname: nickname,
                    avatarText: avatarText,
                    avatarUrl: auth.user?.avatarUrl,
                    onNavigate: _goTo,
                    onToggleExpand: () {
                      final willExpand = !expanded;
                      setState(() {
                        _sidebarExpandedOverride = willExpand;
                        _sidebarShowText = false;
                      });
                      if (willExpand) {
                        Future.delayed(const Duration(milliseconds: 280), () {
                          if (mounted) setState(() => _sidebarShowText = true);
                        });
                      }
                    },
                  ),
                  Expanded(child: widget.navigationShell),
                ],
              ),
            ),
          );
        }

        final selectedIndex = _publicDestinations.indexWhere(
          (item) => item.path == currentPath,
        );
        final showBottomNavigation = selectedIndex >= 0;
        return Scaffold(
          body: CustomPaint(
            painter: _GridPatternPainter(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
            ),
            size: Size.infinite,
            child: widget.navigationShell,
          ),
          bottomNavigationBar:
              showBottomNavigation
                  ? NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected:
                        (index) => _goTo(_publicDestinations[index]),
                    destinations: [
                      for (final item in _publicDestinations)
                        NavigationDestination(
                          icon: item.icon,
                          selectedIcon: item.selectedIcon,
                          label: item.label,
                        ),
                    ],
                  )
                  : null,
        );
      },
    );
  }

  void _goTo(_Destination destination) {
    final branchIndex = _destinations.indexOf(destination);
    widget.navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == widget.navigationShell.currentIndex,
    );
  }
}

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
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      width: expanded ? 164 : 56,
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
    final avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: hasNetworkAvatar
              ? NetworkImage(resolveMediaUrl(avatarUrl!))
              : const AssetImage('assets/images/lacia.png'),
          fit: BoxFit.cover,
        ),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
          mainAxisAlignment:
              showText ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: HugeIcon(
                icon: selected
                    ? (item.selectedIcon as HugeIcon).icon
                    : (item.icon as HugeIcon).icon,
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
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ],
              ).animate().fade(begin: 0, duration: 200.ms, curve: Curves.easeOut),
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
            mainAxisAlignment:
                showText ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: HugeIcon(
                  icon: (item.icon as HugeIcon).icon,
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
                ).animate().fade(begin: 0, duration: 200.ms, curve: Curves.easeOut),
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment:
              showText ? MainAxisAlignment.start : MainAxisAlignment.center,
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
              ).animate().fade(begin: 0, duration: 200.ms, curve: Curves.easeOut),
          ],
        ),
      ),
    );

    return expanded
        ? child
        : Tooltip(message: expanded ? '收起' : '展开', child: child);
  }
}

/// 导航目的地数据模型
class _Destination {
  const _Destination(this.path, this.label, this.icon, this.selectedIcon);

  final String path; // 路由路径
  final String label; // 导航标签文本
  final Widget icon; // 未选中图标
  final Widget selectedIcon; // 选中图标
}

/// 所有导航目的地配置列表
final _recommendDestination = _Destination(
  '/',
  '首页',
  const HugeIcon(icon: HugeIcons.strokeRoundedHome01),
  const HugeIcon(icon: HugeIcons.strokeRoundedHome01),
);
final _contentsDestination = _Destination(
  '/contents',
  '全部',
  const HugeIcon(icon: HugeIcons.strokeRoundedBook01),
  const HugeIcon(icon: HugeIcons.strokeRoundedBook01),
);
final _friendsDestination = _Destination(
  '/friends',
  '朋友',
  const HugeIcon(icon: HugeIcons.strokeRoundedLink01),
  const HugeIcon(icon: HugeIcons.strokeRoundedLink01),
);
final _aboutDestination = _Destination(
  '/about',
  '关于',
  const HugeIcon(icon: HugeIcons.strokeRoundedUserCircle),
  const HugeIcon(icon: HugeIcons.strokeRoundedUserCircle),
);
final _profileDestination = _Destination(
  '/profile',
  '我的',
  const HugeIcon(icon: HugeIcons.strokeRoundedUser),
  const HugeIcon(icon: HugeIcons.strokeRoundedUser),
);
final _adminDestination = _Destination(
  '/admin',
  '管理',
  const HugeIcon(icon: HugeIcons.strokeRoundedSettings01),
  const HugeIcon(icon: HugeIcons.strokeRoundedSettings01),
);
final _loginDestination = _Destination(
  '/login',
  '登录',
  const HugeIcon(icon: HugeIcons.strokeRoundedLogin01),
  const HugeIcon(icon: HugeIcons.strokeRoundedLogin01),
);

final _destinations = <_Destination>[
  _recommendDestination,
  _contentsDestination,
  _friendsDestination,
  _aboutDestination,
  _profileDestination,
  _adminDestination,
  _loginDestination,
];

final _publicDestinations = <_Destination>[
  _recommendDestination,
  _contentsDestination,
  _friendsDestination,
  _aboutDestination,
];

class _GridPatternPainter extends CustomPainter {
  _GridPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const step = 40.0;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
