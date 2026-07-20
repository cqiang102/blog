import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../theme/app_spacing.dart';
import 'admin_filters.dart';

class AdminShellHeader extends StatelessWidget {
  const AdminShellHeader({
    super.key,
    required this.title,
    required this.module,
    this.trailing,
  });

  final String title;
  final String module;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.36),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        module,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.md),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminListActions extends StatelessWidget {
  const AdminListActions({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: actions,
      ),
    );
  }
}

class AdminRowFooter extends StatelessWidget {
  const AdminRowFooter({
    super.key,
    required this.metadata,
    this.actions = const [],
    this.stackBreakpoint = 680,
  });

  final List<Widget> metadata;
  final List<Widget> actions;
  final double stackBreakpoint;

  @override
  Widget build(BuildContext context) {
    final metadataGroup = Wrap(
      spacing: AppSpacing.sm + 4,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: metadata,
    );
    if (actions.isEmpty) return metadataGroup;

    final actionGroup = Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: actions,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < stackBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              metadataGroup,
              const SizedBox(height: AppSpacing.sm + 4),
              Align(alignment: Alignment.centerRight, child: actionGroup),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: metadataGroup),
            const SizedBox(width: AppSpacing.md),
            actionGroup,
          ],
        );
      },
    );
  }
}

class SectionToolbar extends StatelessWidget {
  const SectionToolbar({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondaryAction,
  });

  final String title;
  final String actionLabel;
  final Widget actionIcon;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final Widget? secondaryIcon;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            if (secondaryLabel != null)
              OutlinedButton.icon(
                onPressed: onSecondaryAction,
                style: adminCompactButtonStyle(),
                icon: secondaryIcon ?? const Icon(Icons.add),
                label: Text(secondaryLabel!),
              ),
            FilledButton.icon(
              onPressed: onAction,
              style: adminCompactButtonStyle(),
              icon: actionIcon,
              label: Text(actionLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class AdminNumberField extends StatelessWidget {
  const AdminNumberField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kAdminNumberFieldWidth,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return null;
          return int.tryParse(text) == null ? '请输入数字' : null;
        },
      ),
    );
  }
}
