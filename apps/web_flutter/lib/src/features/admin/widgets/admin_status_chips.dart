import 'package:flutter/material.dart';

import '../../../core/models.dart';

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.status});

  final ContentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      ContentStatus.published => scheme.primaryContainer,
      ContentStatus.archived => scheme.errorContainer,
      ContentStatus.draft => scheme.secondaryContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

class AdminCommentStatusChip extends StatelessWidget {
  const AdminCommentStatusChip({super.key, required this.status});

  final AdminCommentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      AdminCommentStatus.visible => scheme.primaryContainer,
      AdminCommentStatus.pending => scheme.secondaryContainer,
      AdminCommentStatus.blocked => scheme.tertiaryContainer,
      AdminCommentStatus.deleted => scheme.errorContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

class AdminUserRoleChip extends StatelessWidget {
  const AdminUserRoleChip({super.key, required this.role});

  final AdminUserRole role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (role) {
      AdminUserRole.admin => scheme.tertiaryContainer,
      AdminUserRole.user => scheme.secondaryContainer,
    };
    return Chip(label: Text(role.label), backgroundColor: color);
  }
}

class AdminUserStatusChip extends StatelessWidget {
  const AdminUserStatusChip({super.key, required this.status});

  final AdminUserStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      AdminUserStatus.active => scheme.primaryContainer,
      AdminUserStatus.disabled => scheme.errorContainer,
    };
    return Chip(label: Text(status.label), backgroundColor: color);
  }
}

class AdminMetaText extends StatelessWidget {
  const AdminMetaText({super.key, required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = Tooltip(
          message: text,
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 4),
            if (constraints.hasBoundedWidth) Flexible(child: label) else label,
          ],
        );
      },
    );
  }
}
