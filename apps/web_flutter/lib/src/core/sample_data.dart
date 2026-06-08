// 开发用模拟数据
// 提供离线开发时使用的示例内容、友链和管理后台指标

import 'models.dart';

/// 示例内容列表
final sampleContents = <BlogContent>[
  BlogContent(
    id: '00000000-0000-0000-0000-000000000001',
    title: '置顶：我的博客启动计划',
    type: ContentType.markdown,
    summary: '从工程骨架、内容管理到 AI 助手，把个人博客做成一个长期可维护的小产品。',
    coverUrl:
        'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=1200&q=80',
    tags: ['Flutter', 'Spring Boot', 'AI'],
    pinned: true, // 置顶
    likeCount: 42,
    viewCount: 2048,
    publishedAt: DateTime(2026, 6, 1),
    markdown: '''
# 我的博客启动计划

这是第一版工程骨架：前端用 Flutter Web，后端用 Spring Boot 4，AI 能基于知识库和博客内容回答问题。

```dart
final route = GoRoute(path: '/contents/:id');
```

接下来会补齐真实接口、权限、媒体上传和后台管理。
''',
    mediaUrls: [
      'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?auto=format&fit=crop&w=1200&q=80',
    ],
  ),
  BlogContent(
    id: '00000000-0000-0000-0000-000000000002',
    title: '一组生活照片',
    type: ContentType.image,
    summary: '图片内容使用画廊模式，适合记录旅行、桌面和日常瞬间。',
    coverUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
    tags: ['生活', '摄影'],
    pinned: false,
    likeCount: 31,
    viewCount: 980,
    publishedAt: DateTime(2026, 5, 28),
    markdown: '图片内容支持多图和说明文字。',
    mediaUrls: [
      'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=900&q=80',
      'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=900&q=80',
    ],
  ),
  BlogContent(
    id: '00000000-0000-0000-0000-000000000003',
    title: '一次短视频记录',
    type: ContentType.video,
    summary: '视频内容预留播放器、封面和元数据，后续接 MinIO 媒体文件。',
    coverUrl:
        'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=1200&q=80',
    tags: ['视频', '记录'],
    pinned: false,
    likeCount: 19,
    viewCount: 732,
    publishedAt: DateTime(2026, 5, 20),
    markdown: '视频详情会展示播放器、简介、评论和推荐内容。',
  ),
];

/// 示例友情链接列表
final sampleFriends = <FriendLink>[
  const FriendLink(
    id: '10000000-0000-0000-0000-000000000001',
    name: 'River Notes',
    intro: '写技术和生活的朋友。',
    avatarUrl:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
    siteUrl: 'https://example.com',
  ),
  const FriendLink(
    id: '10000000-0000-0000-0000-000000000002',
    name: '小栈',
    intro: '前端、摄影、咖啡。',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
    siteUrl: 'https://example.org',
  ),
  const FriendLink(
    id: '10000000-0000-0000-0000-000000000003',
    name: 'North Lab',
    intro: '后端和 AI 工程笔记。',
    avatarUrl:
        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
    siteUrl: 'https://example.net',
  ),
];

/// 示例管理后台指标数据
final adminMetrics = <AdminMetric>[
  const AdminMetric('内容', '3'),
  const AdminMetric('媒体', '5'),
  const AdminMetric('朋友', '3'),
  const AdminMetric('用户', '1'),
  const AdminMetric('评论', '12'),
  const AdminMetric('点赞', '92'),
  const AdminMetric('浏览', '3.8k'),
  const AdminMetric('今日 AI', '0'),
];
