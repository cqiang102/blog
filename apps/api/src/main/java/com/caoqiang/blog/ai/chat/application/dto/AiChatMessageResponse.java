package com.caoqiang.blog.ai.chat.application.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * AI 聊天消息响应 DTO。
 *
 * @param id           消息 ID
 * @param role         消息角色（USER、ASSISTANT、TOOL、SYSTEM）
 * @param content      消息内容
 * @param auditStatus  审核状态（VISIBLE / BLOCKED / null 表示未审核）
 * @param createdAt    创建时间
 */
public record AiChatMessageResponse(
        UUID id,
        String role,
        String content,
        String auditStatus,
        Instant createdAt
) {
}
