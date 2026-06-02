package com.caoqiang.blog.interaction;

import java.time.Instant;
import java.util.UUID;

public record AdminLikeResponse(
        UUID id,
        UUID contentId,
        String contentTitle,
        UUID userId,
        String userNickname,
        String userEmail,
        Instant createdAt
) {

    public static AdminLikeResponse from(Like like) {
        return new AdminLikeResponse(
                like.getId(),
                like.getContent().getId(),
                like.getContent().getTitle(),
                like.getUser().getId(),
                like.getUser().getNickname(),
                like.getUser().getEmail(),
                like.getCreatedAt()
        );
    }
}
