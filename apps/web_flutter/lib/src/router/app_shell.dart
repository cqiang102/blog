// 响应式 Shell 布局组件
// 纯展示组件和导航配置拆分在同名目录的 part 文件中

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/constants.dart';
import '../core/media_url.dart';
import '../state/state.dart';
import '../theme/app_design_tokens.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';

part 'app_shell/brand_sidebar.dart';
part 'app_shell/grid_pattern_painter.dart';
part 'app_shell/navigation_destinations.dart';

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
  Timer? _sidebarTextTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prewarmPublicData().catchError((_) {}));
    });
  }

  @override
  void dispose() {
    _sidebarTextTimer?.cancel();
    super.dispose();
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
    final avatarText = nickname == null || nickname.isEmpty
        ? 'C'
        : nickname.characters.first;
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
                color: AppDesignTokens.of(context).grid,
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
                      final reduceMotion = AppMotion.reduce(context);
                      _sidebarTextTimer?.cancel();
                      setState(() {
                        _sidebarExpandedOverride = willExpand;
                        _sidebarShowText = willExpand && reduceMotion;
                      });
                      if (willExpand && !reduceMotion) {
                        _sidebarTextTimer = Timer(
                          const Duration(milliseconds: 280),
                          () {
                            if (mounted) {
                              setState(() => _sidebarShowText = true);
                            }
                          },
                        );
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
              color: AppDesignTokens.of(context).grid,
            ),
            size: Size.infinite,
            child: widget.navigationShell,
          ),
          bottomNavigationBar: showBottomNavigation
              ? NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      _goTo(_publicDestinations[index]),
                  destinations: [
                    for (final item in _publicDestinations)
                      NavigationDestination(
                        icon: HugeIcon(icon: item.icon),
                        selectedIcon: HugeIcon(icon: item.selectedIcon),
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
