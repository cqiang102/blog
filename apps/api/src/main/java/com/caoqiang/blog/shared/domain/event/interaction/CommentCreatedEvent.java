package com.caoqiang.blog.shared.domain.event.interaction;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.UUID;

public class CommentCreatedEvent extends DomainEvent {

    private final UUID commentId;
    private final UUID contentId;
    private final UUID userId;

    public CommentCreatedEvent(UUID commentId, UUID contentId, UUID userId) {
        this.commentId = commentId;
        this.contentId = contentId;
        this.userId = userId;
    }

    public UUID getCommentId() {
        return commentId;
    }

    public UUID getContentId() {
        return contentId;
    }

    public UUID getUserId() {
        return userId;
    }
}
