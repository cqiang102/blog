package com.caoqiang.blog.content;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record ContentDetailResponse(
        UUID id,
        String title,
        String slug,
        ContentType type,
        ContentStatus status,
        String summary,
        String bodyMarkdown,
        String coverUrl,
        List<String> tags,
        List<MediaAssetResponse> mediaAssets,
        boolean likedByCurrentUser,
        long likeCount,
        long viewCount,
        long commentCount,
        Instant publishedAt
) {
}
