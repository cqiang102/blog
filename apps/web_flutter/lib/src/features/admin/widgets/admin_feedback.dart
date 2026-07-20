import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/api/api_exception.dart';

String adminErrorMessage(Object error) => userFacingErrorMessage(error);

class AdminInlineError extends StatelessWidget {
  const AdminInlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert01,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class AdminErrorPane extends StatelessWidget {
  const AdminErrorPane({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminEmptyPane extends StatelessWidget {
  const AdminEmptyPane({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(child: Text(message)),
    );
  }
}

void showAdminSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
