package com.caoqiang.blog.interaction;

import com.caoqiang.blog.content.Content;
import java.time.Instant;
import java.util.UUID;

public record UserActivityResponse(
        UUID id,
        String type,
        UUID contentId,
        String title,
        Instant createdAt
) {

    public static UserActivityResponse comment(UUID id, Content content, Instant createdAt) {
        return new UserActivityResponse(id, "COMMENT", content.getId(), content.getTitle(), createdAt);
    }

    public static UserActivityResponse like(Content content, Instant createdAt) {
        return new UserActivityResponse(content.getId(), "LIKE", content.getId(), content.getTitle(), createdAt);
    }

    public static UserActivityResponse view(UUID id, Content content, Instant createdAt) {
        return new UserActivityResponse(id, "VIEW", content.getId(), content.getTitle(), createdAt);
    }
}
