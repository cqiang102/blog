package com.caoqiang.blog.content.application.api;

import java.util.UUID;

/** Immutable content data exposed to interaction workflows. */
public record ContentInteractionSnapshot(
        UUID id,
        String title,
        long likeCount,
        long viewCount,
        long commentCount
) {
}
