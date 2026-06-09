package com.caoqiang.blog.shared.domain.event.content;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.UUID;

public class ContentArchivedEvent extends DomainEvent {

    private final UUID contentId;

    public ContentArchivedEvent(UUID contentId) {
        this.contentId = contentId;
    }

    public UUID getContentId() {
        return contentId;
    }
}
