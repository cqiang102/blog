package com.caoqiang.blog.ai.chat.application.dto;

import com.caoqiang.blog.ai.chat.domain.model.AiChatMessage;
import com.caoqiang.blog.ai.chat.domain.model.AiMessageRole;
import java.time.Instant;
import java.util.UUID;

/**
 * 管理端 AI 聊天消息响应 DTO
 * <p>
 * 用于管理端展示 AI 聊天消息的详细信息，包含 Token 使用统计。
 *
 * @param id               消息 ID
 * @param role             消息角色（USER/ASSISTANT/SYSTEM/TOOL）
 * @param content          消息内容
 * @param toolName         工具名称（仅 TOOL 角色）
 * @param promptTokens     输入 Token 数量
 * @param completionTokens 输出 Token 数量
 * @param createdAt        创建时间
 */
public record AdminAiChatMessageResponse(
        UUID id,
        AiMessageRole role,
        String content,
        String toolName,
        Integer promptTokens,
        Integer completionTokens,
        String auditStatus,
        String auditReason,
        Instant createdAt
) {

    /**
     * 从消息实体创建响应 DTO
     *
     * @param message AI 聊天消息实体
     * @return 管理端消息响应 DTO
     */
    public static AdminAiChatMessageResponse from(AiChatMessage message) {
        return new AdminAiChatMessageResponse(
                message.getId(),
                message.getRole(),
                message.getContent(),
                message.getToolName(),
                message.getPromptTokens(),
                message.getCompletionTokens(),
                message.getAuditStatus(),
                message.getAuditReason(),
                message.getCreatedAt()
        );
    }
}
