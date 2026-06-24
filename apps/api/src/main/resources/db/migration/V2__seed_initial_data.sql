INSERT INTO tags (id, name, slug, description)
VALUES
    ('10000000-0000-0000-0000-000000000001', 'Flutter', 'flutter', 'Flutter Web 和客户端开发'),
    ('10000000-0000-0000-0000-000000000002', 'Spring Boot', 'spring-boot', 'Java 后端与服务端工程'),
    ('10000000-0000-0000-0000-000000000003', 'AI', 'ai', 'AI 助手、RAG 和工具调用'),
    ('10000000-0000-0000-0000-000000000004', '生活', 'life', '生活记录与随笔')
ON CONFLICT (id) DO NOTHING;

INSERT INTO contents (
    id, title, slug, type, status, summary, body_markdown, pinned,
    like_count, view_count, comment_count, published_at
)
VALUES
    (
        '20000000-0000-0000-0000-000000000001',
        '置顶：我的博客启动计划',
        'blog-launch-plan',
        'ARTICLE',
        'PUBLISHED',
        '从工程骨架到 AI 助手，记录这个博客的第一版路线。',
        '# 置顶：我的博客启动计划

这个博客会先完成内容、登录、评论、点赞和后台管理，再逐步接入 Spring AI 与个人知识库。',
        true,
        42,
        2048,
        0,
        now() - interval '3 days'
    ),
    (
        '20000000-0000-0000-0000-000000000002',
        '用 Flutter 和 Spring Boot 做个人博客',
        'flutter-spring-boot-blog',
        'ARTICLE',
        'PUBLISHED',
        '前端使用 Flutter Web，后端使用 Spring Boot 4，先把 MVP 闭环跑起来。',
        '# 用 Flutter 和 Spring Boot 做个人博客

Monorepo 会把 Flutter Web、Spring Boot API、Docker Compose 和文档放在一起，方便持续演进。',
        false,
        31,
        512,
        0,
        now() - interval '2 days'
    ),
    (
        '20000000-0000-0000-0000-000000000003',
        '一组生活照片',
        'life-gallery',
        'IMAGE',
        'PUBLISHED',
        '图片内容会使用画廊模式展示。',
        null,
        false,
        18,
        260,
        0,
        now() - interval '1 day'
    )
ON CONFLICT (id) DO NOTHING;

INSERT INTO media_assets (
    id, content_id, type, bucket, object_key, public_url, filename, content_type, byte_size, width, height
)
VALUES
    (
        '30000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001',
        'IMAGE',
        'external',
        'unsplash/code',
        'https://images.unsplash.com/photo-1515879218367-8466d910aaa4',
        'code.jpg',
        'image/jpeg',
        0,
        1600,
        900
    ),
    (
        '30000000-0000-0000-0000-000000000002',
        '20000000-0000-0000-0000-000000000002',
        'IMAGE',
        'external',
        'unsplash/workspace',
        'https://images.unsplash.com/photo-1497366754035-f200968a6e72',
        'workspace.jpg',
        'image/jpeg',
        0,
        1600,
        900
    ),
    (
        '30000000-0000-0000-0000-000000000003',
        '20000000-0000-0000-0000-000000000003',
        'IMAGE',
        'external',
        'unsplash/life',
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',
        'life.jpg',
        'image/jpeg',
        0,
        1600,
        900
    )
ON CONFLICT (id) DO NOTHING;

UPDATE contents
SET cover_media_id = '30000000-0000-0000-0000-000000000001'
WHERE id = '20000000-0000-0000-0000-000000000001' AND cover_media_id IS NULL;

UPDATE contents
SET cover_media_id = '30000000-0000-0000-0000-000000000002'
WHERE id = '20000000-0000-0000-0000-000000000002' AND cover_media_id IS NULL;

UPDATE contents
SET cover_media_id = '30000000-0000-0000-0000-000000000003'
WHERE id = '20000000-0000-0000-0000-000000000003' AND cover_media_id IS NULL;

INSERT INTO content_tags (content_id, tag_id)
VALUES
    ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001'),
    ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002'),
    ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003'),
    ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001'),
    ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002'),
    ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000004')
ON CONFLICT DO NOTHING;

INSERT INTO friends (id, name, avatar_url, intro, site_url, visible, sort_order)
VALUES
    (
        '40000000-0000-0000-0000-000000000001',
        'River Notes',
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        '写技术和生活的朋友',
        'https://example.com',
        true,
        10
    ),
    (
        '40000000-0000-0000-0000-000000000002',
        '小栈',
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
        '前端、摄影、咖啡',
        'https://example.org',
        true,
        20
    )
ON CONFLICT (id) DO NOTHING;
