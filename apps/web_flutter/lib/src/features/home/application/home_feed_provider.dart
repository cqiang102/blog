import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models.dart';
import '../../../state/content_providers.dart';

final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final recommendations = await ref.watch(recommendationsProvider.future);
  return HomeFeed.fromRecommendations(recommendations);
});

class HomeFeed {
  const HomeFeed({
    required this.featured,
    required this.latest,
    required this.mostLiked,
  });

  final BlogContent? featured;
  final List<BlogContent> latest;
  final List<BlogContent> mostLiked;

  factory HomeFeed.fromRecommendations(Recommendations recommendations) {
    final featured = recommendations.pinned.isNotEmpty
        ? recommendations.pinned.first
        : recommendations.latest.isEmpty
        ? null
        : recommendations.latest.first;
    final latest = recommendations.pinned.isNotEmpty
        ? recommendations.latest
              .where((content) => content.id != featured!.id)
              .toList()
        : recommendations.latest;
    return HomeFeed(
      featured: featured,
      latest: latest.isEmpty ? recommendations.latest : latest,
      mostLiked: recommendations.mostLiked,
    );
  }
}
