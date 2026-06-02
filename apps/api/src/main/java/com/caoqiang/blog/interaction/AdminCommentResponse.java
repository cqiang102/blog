package com.caoqiang.blog.interaction;

import java.time.Instant;
import java.util.UUID;

public record AdminCommentResponse(
        UUID id,
        UUID contentId,
        String contentTitle,
        UUID userId,
        String userNickname,
        String userEmail,
        CommentStatus status,
        String body,
        Instant createdAt,
        Instant updatedAt
) {

    public static AdminCommentResponse from(Comment comment) {
        return new AdminCommentResponse(
                comment.getId(),
                comment.getContent().getId(),
                comment.getContent().getTitle(),
                comment.getUser().getId(),
                comment.getUser().getNickname(),
                comment.getUser().getEmail(),
                comment.getStatus(),
                comment.getBody(),
                comment.getCreatedAt(),
                comment.getUpdatedAt()
        );
    }
}
