import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_providers.dart';
import '../../core/models.dart';

class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('朋友们')),
        friends.when(
          loading:
              () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (error, stackTrace) => SliverFillRemaining(
                child: _FriendsError(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(friendsProvider),
                ),
              ),
          data: (items) {
            if (items.isEmpty) {
              return const SliverFillRemaining(
                child: Center(child: Text('暂无朋友链接')),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverGrid.builder(
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisExtent: 172,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  return _FriendCard(friend: items[index]);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friend});

  final FriendLink friend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap:
            () => launchUrl(
              Uri.parse(friend.siteUrl),
              webOnlyWindowName: '_blank',
            ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage:
                        friend.avatarUrl.isEmpty
                            ? null
                            : NetworkImage(friend.avatarUrl),
                    radius: 28,
                    child:
                        friend.avatarUrl.isEmpty
                            ? Text(
                              friend.name.isEmpty
                                  ? '?'
                                  : friend.name.substring(0, 1),
                            )
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      friend.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.open_in_new),
                ],
              ),
              const SizedBox(height: 16),
              Text(friend.intro, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendsError extends StatelessWidget {
  const _FriendsError({required this.message, required this.onRetry});

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
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
