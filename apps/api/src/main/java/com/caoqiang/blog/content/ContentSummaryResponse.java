package com.caoqiang.blog.content;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record ContentSummaryResponse(
        UUID id,
        String title,
        String slug,
        ContentType type,
        String summary,
        String coverUrl,
        boolean pinned,
        long likeCount,
        Instant publishedAt,
        List<String> tags
) {
}
