package com.caoqiang.blog.ai;

import java.time.Instant;
import java.util.UUID;

public record AiChatSessionResponse(
        UUID id,
        String title,
        int messageCount,
        Instant createdAt,
        Instant updatedAt
) {
}
