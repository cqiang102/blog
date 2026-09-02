import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/features/home/application/home_feed_provider.dart';

void main() {
  test('builds a home feed without duplicating the featured item', () {
    final featured = _content('featured', pinned: true);
    final latest = _content('latest');
    final popular = _content('popular');

    final feed = HomeFeed.fromRecommendations(
      Recommendations(
        pinned: [featured],
        latest: [featured, latest],
        mostLiked: [popular],
      ),
    );

    expect(feed.featured?.id, 'featured');
    expect(feed.latest.map((item) => item.id), ['latest']);
    expect(feed.mostLiked.single.id, 'popular');
  });

  test('falls back to latest content when there is no pinned item', () {
    final first = _content('first');
    final second = _content('second');

    final feed = HomeFeed.fromRecommendations(
      Recommendations(
        pinned: const [],
        latest: [first, second],
        mostLiked: const [],
      ),
    );

    expect(feed.featured?.id, 'first');
    // 无置顶时，hero 取最新一篇，但“最近更新”仍展示全部最新内容
    expect(feed.latest.map((item) => item.id), ['first', 'second']);
  });
}

BlogContent _content(String id, {bool pinned = false}) {
  return BlogContent(
    id: id,
    title: id,
    type: ContentType.markdown,
    summary: 'summary',
    coverUrl: '',
    tags: const [],
    pinned: pinned,
    likeCount: 0,
    publishedAt: DateTime.utc(2026, 7, 13),
  );
}
