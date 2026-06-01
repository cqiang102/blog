enum ContentType {
  text,
  article,
  image,
  video;

  String get label {
    return switch (this) {
      ContentType.text => '文本',
      ContentType.article => '图文',
      ContentType.image => '图片',
      ContentType.video => '视频',
    };
  }
}

class BlogContent {
  const BlogContent({
    required this.id,
    required this.title,
    required this.type,
    required this.summary,
    required this.coverUrl,
    required this.tags,
    required this.pinned,
    required this.likeCount,
    required this.viewCount,
    required this.publishedAt,
    required this.markdown,
    this.mediaUrls = const [],
  });

  final String id;
  final String title;
  final ContentType type;
  final String summary;
  final String coverUrl;
  final List<String> tags;
  final bool pinned;
  final int likeCount;
  final int viewCount;
  final DateTime publishedAt;
  final String markdown;
  final List<String> mediaUrls;
}

class FriendLink {
  const FriendLink({
    required this.name,
    required this.intro,
    required this.avatarUrl,
    required this.siteUrl,
  });

  final String name;
  final String intro;
  final String avatarUrl;
  final String siteUrl;
}

class AdminMetric {
  const AdminMetric(this.label, this.value);

  final String label;
  final String value;
}
