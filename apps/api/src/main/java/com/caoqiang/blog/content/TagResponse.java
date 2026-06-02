package com.caoqiang.blog.content;

import java.util.UUID;

public record TagResponse(UUID id, String name, String slug, String description) {

    public static TagResponse from(Tag tag) {
        return new TagResponse(tag.getId(), tag.getName(), tag.getSlug(), tag.getDescription());
    }
}
