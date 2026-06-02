package com.caoqiang.blog.content;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record AdminContentResponse(
        UUID id,
        String title,
        String slug,
        ContentType type,
        ContentStatus status,
        String summary,
        String bodyMarkdown,
        boolean pinned,
        long likeCount,
        long viewCount,
        long commentCount,
        Instant publishedAt,
        List<TagResponse> tags
) {

    public static AdminContentResponse from(Content content) {
        return new AdminContentResponse(
                content.getId(),
                content.getTitle(),
                content.getSlug(),
                content.getType(),
                content.getStatus(),
                content.getSummary(),
                content.getBodyMarkdown(),
                content.isPinned(),
                content.getLikeCount(),
                content.getViewCount(),
                content.getCommentCount(),
                content.getPublishedAt(),
                content.getTags().stream().map(TagResponse::from).toList()
        );
    }
}
