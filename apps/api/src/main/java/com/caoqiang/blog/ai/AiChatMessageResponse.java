package com.caoqiang.blog.ai;

import java.time.Instant;
import java.util.UUID;

public record AiChatMessageResponse(
        UUID id,
        String role,
        String content,
        Instant createdAt
) {
}
