package com.caoqiang.blog.shared.domain.event.interaction;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.UUID;

public class LikeRemovedEvent extends DomainEvent {

    private final UUID contentId;
    private final UUID userId;

    public LikeRemovedEvent(UUID contentId, UUID userId) {
        this.contentId = contentId;
        this.userId = userId;
    }

    public UUID getContentId() {
        return contentId;
    }

    public UUID getUserId() {
        return userId;
    }
}
