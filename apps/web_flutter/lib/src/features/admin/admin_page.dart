// 管理后台模块
// 管理后台主页 Shell，导入各标签页模块并组装 TabBar
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/constants.dart';
import '../../state/state.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/widgets.dart';
import 'admin_tab_registry.dart';
import 'admin_widgets.dart';

/// 管理后台主页 Widget
/// 仅 ADMIN 可访问，路由守卫负责权限校验，此处保留防御性状态展示。
/// 添加 AutomaticKeepAliveClientMixin 保持页面状态
class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key, this.initialTab = AdminTabId.overview});

  final AdminTabId initialTab;

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage>
    with AutomaticKeepAliveClientMixin {
  late AdminTabId _selectedTab;
  late final Set<AdminTabId> _visitedTabs;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _visitedTabs = {widget.initialTab};
  }

  @override
  void didUpdateWidget(covariant AdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab) return;
    _selectedTab = widget.initialTab;
    _visitedTabs.add(widget.initialTab);
  }

  @override
  bool get wantKeepAlive => true;

  void _selectTab(AdminTabId tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
      _visitedTabs.add(tab);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = ref.watch(authControllerProvider);
    final isAdmin = auth.user?.isAdmin ?? false;

    if (!auth.isLoaded || (auth.isAuthenticated && auth.user == null)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('管理员中心'),
          actions: const [AppThemeToggle()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('管理员中心'),
          actions: const [AppThemeToggle()],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('当前账号没有管理员权限'),
              ),
            ),
          ),
        ),
      );
    }

    final selectedIndex = adminTabIndex(_selectedTab);

    return AppPageFrame(
      child: Column(
        children: [
          AdminShellHeader(
            title: '管理后台',
            module: adminTabs[selectedIndex].label,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppThemeToggle(),
                const SizedBox(width: AppSpacing.sm),
                IconButton.outlined(
                  tooltip: '刷新当前管理数据',
                  onPressed: () => _refresh(ref),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(kAdminDenseControlHeight),
                    fixedSize: const Size.square(kAdminDenseControlHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pages = IndexedStack(
                  index: selectedIndex,
                  children: [
                    for (final tab in adminTabs)
                      _visitedTabs.contains(tab.id)
                          ? tab.page
                          : const SizedBox.shrink(),
                  ],
                );
                void select(int index) {
                  final tab = adminTabs[index];
                  _selectTab(tab.id);
                  context.go(tab.location);
                }

                if (constraints.maxWidth >= kWideBreakpoint) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 208,
                        child: _AdminDesktopNavigation(
                          selectedIndex: selectedIndex,
                          onSelected: select,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: pages),
                    ],
                  );
                }

                return Column(
                  children: [
                    AppHorizontalTabs(
                      labels: adminTabs.map((tab) => tab.label).toList(),
                      selectedIndex: selectedIndex,
                      onSelected: select,
                    ),
                    Expanded(child: pages),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 刷新所有管理数据
  /// 使所有管理相关的 Provider 失效，触发重新加载
  void _refresh(WidgetRef ref) {
    invalidateAllAdminData(ref);
  }
}

class _AdminDesktopNavigation extends StatelessWidget {
  const _AdminDesktopNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final design = AppDesignTokens.of(context);
    final children = <Widget>[];
    String? currentGroup;
    for (var index = 0; index < adminTabs.length; index++) {
      final tab = adminTabs[index];
      if (currentGroup != tab.group) {
        currentGroup = tab.group;
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: AppSpacing.md));
        }
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Text(
              tab.group,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.1,
              ),
            ),
          ),
        );
      }
      final selected = index == selectedIndex;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: ListTile(
            selected: selected,
            selectedColor: scheme.primary,
            selectedTileColor: design.mint,
            leading: Icon(tab.icon, size: 20),
            title: Text(tab.label),
            dense: true,
            minTileHeight: 44,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            onTap: () => onSelected(index),
          ),
        ),
      );
    }

    return ColoredBox(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.68),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: children,
      ),
    );
  }
}
