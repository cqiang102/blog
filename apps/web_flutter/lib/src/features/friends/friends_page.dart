import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/sample_data.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final friends = [...sampleFriends]..shuffle();

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('朋友们')),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverGrid.builder(
            itemCount: friends.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 172,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final friend = friends[index];
              return Card(
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse(friend.siteUrl), webOnlyWindowName: '_blank'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundImage: NetworkImage(friend.avatarUrl), radius: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                friend.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
            },
          ),
        ),
      ],
    );
  }
}
