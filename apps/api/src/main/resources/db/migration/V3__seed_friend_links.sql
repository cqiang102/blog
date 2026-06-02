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
