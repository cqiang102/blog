part of '../app_shell.dart';

/// 导航目的地数据模型。
class _Destination {
  const _Destination(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final List<List<dynamic>> icon;
  final List<List<dynamic>> selectedIcon;
}

/// 所有导航目的地配置列表。
final _recommendDestination = const _Destination(
  '/',
  '首页',
  HugeIcons.strokeRoundedHome01,
  HugeIcons.strokeRoundedHome01,
);
final _contentsDestination = const _Destination(
  '/contents',
  '全部',
  HugeIcons.strokeRoundedBook01,
  HugeIcons.strokeRoundedBook01,
);
final _friendsDestination = const _Destination(
  '/friends',
  '朋友',
  HugeIcons.strokeRoundedLink01,
  HugeIcons.strokeRoundedLink01,
);
final _aboutDestination = const _Destination(
  '/about',
  '关于',
  HugeIcons.strokeRoundedUserCircle,
  HugeIcons.strokeRoundedUserCircle,
);
final _profileDestination = const _Destination(
  '/profile',
  '我的',
  HugeIcons.strokeRoundedUser,
  HugeIcons.strokeRoundedUser,
);
final _adminDestination = const _Destination(
  '/admin',
  '管理',
  HugeIcons.strokeRoundedSettings01,
  HugeIcons.strokeRoundedSettings01,
);
final _loginDestination = const _Destination(
  '/login',
  '登录',
  HugeIcons.strokeRoundedLogin01,
  HugeIcons.strokeRoundedLogin01,
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
