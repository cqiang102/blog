package com.caoqiang.blog.interaction;

import java.time.Instant;
import java.util.UUID;

public record CommentResponse(
        UUID id,
        UUID contentId,
        String contentTitle,
        String body,
        CommentAuthor author,
        String auditStatus,
        Instant createdAt
) {

    public static CommentResponse from(Comment comment) {
        return new CommentResponse(
                comment.getId(),
                comment.getContent().getId(),
                comment.getContent().getTitle(),
                comment.getBody(),
                new CommentAuthor(
                        comment.getUser().getId(),
                        comment.getUser().getNickname(),
                        comment.getUser().getAvatarUrl()
                ),
                comment.getAuditStatus(),
                comment.getCreatedAt()
        );
    }

    public record CommentAuthor(UUID id, String nickname, String avatarUrl) {
    }
}
