import 'package:flutter/material.dart';

import 'tabs/ai_chat_admin_tab.dart';
import 'tabs/audit_log_admin_tab.dart';
import 'tabs/comment_admin_tab.dart';
import 'tabs/content_admin_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/friend_admin_tab.dart';
import 'tabs/interaction_admin_tab.dart';
import 'tabs/knowledge_admin_tab.dart';
import 'tabs/tag_admin_tab.dart';
import 'tabs/user_admin_tab.dart';

/// 管理后台标签页的稳定标识。
enum AdminTabId {
  overview('overview'),
  content('content'),
  comments('comments'),
  likes('likes'),
  views('views'),
  friends('friends'),
  tags('tags'),
  users('users'),
  ai('ai'),
  knowledge('knowledge'),
  logs('logs');

  const AdminTabId(this.routeValue);

  final String routeValue;
}

/// 标签页的路由、导航和页面元数据。
class AdminTabDefinition {
  const AdminTabDefinition({
    required this.id,
    required this.label,
    required this.group,
    required this.icon,
    required this.page,
  });

  final AdminTabId id;
  final String label;
  final String group;
  final IconData icon;
  final Widget page;

  String get location => adminTabLocation(id);
}

/// 管理后台唯一的标签页顺序和展示配置。
const adminTabs = <AdminTabDefinition>[
  AdminTabDefinition(
    id: AdminTabId.overview,
    label: '概览',
    group: '工作台',
    icon: Icons.space_dashboard_outlined,
    page: AdminDashboardTab(),
  ),
  AdminTabDefinition(
    id: AdminTabId.content,
    label: '内容',
    group: '内容',
    icon: Icons.article_outlined,
    page: AdminContentTab(),
  ),
  AdminTabDefinition(
    id: AdminTabId.comments,
    label: '评论',
    group: '内容',
    icon: Icons.mode_comment_outlined,
    page: AdminCommentTab(),
  ),
  AdminTabDefinition(
    id: AdminTabId.likes,
    label: '点赞',
    group: '内容',
    icon: Icons.favorite_border_rounded,
    page: AdminLikeTab(),
  ),
  AdminTabDefinition(
    id: AdminTabId.views,
    label: '浏览',
    group: '内容',
    icon: Icons.visibility_outlined,
    page: AdminViewTab(),
  ),
  AdminTabDefinition(
    id: AdminTabId.friends,
    label: '朋友',
    group: '运营',
    icon: Icons.link_rounded,
    page: AdminFriendTab(),
  ),
  AdminTabDefinition(
    id: AdminTabId.tags,
    label: '标签',
    group: '运营',
    icon: Icons.label_outline_rounded,
    page: AdminTagTab(),
  ),
  AdminTabDefinition(
    id: AdminTabId.users,
    label: '用户',
    group: '运营',
    icon: Icons.group_outlined,
    page: AdminUserTab(),
  ),
  AdminTabDefinition(
    id: AdminTabId.ai,
    label: 'AI 会话',
    group: 'AI',
    icon: Icons.auto_awesome_outlined,
    page: AdminAiChatTab(),
  ),
  AdminTabDefinition(
    id: AdminTabId.knowledge,
    label: '知识库',
    group: 'AI',
    icon: Icons.library_books_outlined,
    page: AdminKnowledgeTab(),
  ),
  AdminTabDefinition(
    id: AdminTabId.logs,
    label: '日志',
    group: '系统',
    icon: Icons.history_rounded,
    page: AdminAuditLogTab(),
  ),
];

AdminTabId adminTabForUri(Uri uri) {
  if (uri.path.startsWith('/admin/contents/')) {
    return AdminTabId.content;
  }
  final routeValue = uri.queryParameters['tab'];
  return AdminTabId.values.firstWhere(
    (tab) => tab.routeValue == routeValue,
    orElse: () => AdminTabId.overview,
  );
}

int adminTabIndex(AdminTabId id) =>
    adminTabs.indexWhere((definition) => definition.id == id);

String adminTabLocation(AdminTabId id) =>
    Uri(path: '/admin', queryParameters: {'tab': id.routeValue}).toString();
