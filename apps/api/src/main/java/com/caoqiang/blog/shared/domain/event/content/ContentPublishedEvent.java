package com.caoqiang.blog.shared.domain.event.content;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.UUID;

public class ContentPublishedEvent extends DomainEvent {

    private final UUID contentId;
    private final String title;
    private final String slug;

    public ContentPublishedEvent(UUID contentId, String title, String slug) {
        this.contentId = contentId;
        this.title = title;
        this.slug = slug;
    }

    public UUID getContentId() {
        return contentId;
    }

    public String getTitle() {
        return title;
    }

    public String getSlug() {
        return slug;
    }
}
