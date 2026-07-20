package com.caoqiang.blog.ai.chat.application.dto;

import com.caoqiang.blog.ai.chat.domain.model.AiChatMessage;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.user.application.api.IdentityUser;
import java.time.Instant;
import java.util.UUID;

/**
 * 管理端 AI 聊天会话响应 DTO
 * <p>
 * 用于管理端展示 AI 聊天会话的详细信息，包含用户信息和会话统计。
 *
 * @param id            会话 ID
 * @param userId        用户 ID
 * @param userNickname  用户昵称
 * @param userEmail     用户邮箱
 * @param title         会话标题
 * @param messageCount  消息数量
 * @param lastMessage   最后一条消息内容
 * @param createdAt     创建时间
 * @param updatedAt     更新时间
 */
public record AdminAiChatSessionResponse(
        UUID id,
        UUID userId,
        String userNickname,
        String userEmail,
        String title,
        long messageCount,
        String lastMessage,
        Instant createdAt,
        Instant updatedAt) {

    /**
     * 从会话实体创建响应 DTO
     *
     * @param session      AI 聊天会话实体
     * @param messageCount 消息数量
     * @param lastMessage  最后一条消息（可为 null）
     * @return 管理端会话响应 DTO
     */
    public static AdminAiChatSessionResponse from(
            AiChatSession session, IdentityUser user, long messageCount, AiChatMessage lastMessage) {
        return new AdminAiChatSessionResponse(
                session.getId(),
                session.getUserId(),
                user.nickname(),
                user.email(),
                session.getTitle(),
                messageCount,
                lastMessage == null ? null : lastMessage.getContent(),
                session.getCreatedAt(),
                session.getUpdatedAt());
    }
}
