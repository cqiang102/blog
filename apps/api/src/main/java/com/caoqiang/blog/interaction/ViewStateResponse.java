package com.caoqiang.blog.interaction;

import java.util.UUID;

public record ViewStateResponse(UUID contentId, boolean recorded, long viewCount) {
}
