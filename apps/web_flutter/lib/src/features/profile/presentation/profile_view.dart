// 个人中心模块
// 支持资料编辑、修改密码、查看评论/点赞/浏览活动记录、OAuth 账号绑定
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../state/state.dart';
import '../../../widgets/widgets.dart';
import '../../../auth/auth_controller.dart';
import '../../../core/constants.dart';
import '../../../core/media_url.dart';
import '../../../core/models.dart';
import '../../../theme/app_spacing.dart';
import '../application/profile_activity_controller.dart';
import '../application/profile_form_controller.dart';

part 'profile_activity_list.dart';
part 'profile_form.dart';
part 'profile_sections.dart';

/// 个人中心 Widget
/// 使用 TabBar 展示资料、评论、点赞、浏览四个标签页
/// 添加 AutomaticKeepAliveClientMixin 保持页面状态
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  static const _sections = [
    ('个人资料', '编辑头像、昵称与公开信息'),
    ('我的评论', '查看自己的评论记录'),
    ('我的点赞', '查看收藏和点赞过的内容'),
    ('浏览记录', '快速找回最近阅读的内容'),
  ];

  int _selectedIndex = 0;
  final Set<int> _visitedSections = {0};

  @override
  bool get wantKeepAlive => true;

  void _selectSection(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _visitedSections.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = ref.watch(authControllerProvider);

    return AppPageFrame(
      child: Column(
        children: [
          AppPageHeader(
            title: '个人中心',
            // subtitle: _sections[_selectedIndex].$2,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppThemeToggle(),
                IconButton(
                  tooltip: '退出登录',
                  onPressed: auth.isBusy
                      ? null
                      : () => ref.read(authControllerProvider).logout(),
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedLogout01),
                ),
              ],
            ),
          ),
          AppHorizontalTabs(
            labels: _sections.map((item) => item.$1).toList(),
            selectedIndex: _selectedIndex,
            onSelected: _selectSection,
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _visitedSections.contains(0)
                    ? const _ProfileForm()
                    : const SizedBox.shrink(),
                _visitedSections.contains(1)
                    ? const _RecordList(
                        type: ProfileActivityType.comments,
                        label: '评论',
                      )
                    : const SizedBox.shrink(),
                _visitedSections.contains(2)
                    ? const _RecordList(
                        type: ProfileActivityType.likes,
                        label: '点赞',
                      )
                    : const SizedBox.shrink(),
                _visitedSections.contains(3)
                    ? const _RecordList(
                        type: ProfileActivityType.views,
                        label: '浏览',
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
