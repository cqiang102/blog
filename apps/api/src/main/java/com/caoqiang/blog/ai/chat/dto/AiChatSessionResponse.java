package com.caoqiang.blog.ai.chat.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * AI 聊天会话响应 DTO。
 *
 * @param id           会话 ID
 * @param title        会话标题
 * @param messageCount 会话中的消息数量
 * @param createdAt    创建时间
 * @param updatedAt    最后更新时间
 */
public record AiChatSessionResponse(
        UUID id,
        String title,
        int messageCount,
        Instant createdAt,
        Instant updatedAt
) {
}
