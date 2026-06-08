package com.caoqiang.blog.ai.chat.dto;

import com.caoqiang.blog.ai.chat.entity.AiChatMessage;
import com.caoqiang.blog.ai.chat.entity.AiMessageRole;
import java.time.Instant;
import java.util.UUID;

public record AdminAiChatMessageResponse(
        UUID id,
        AiMessageRole role,
        String content,
        String toolName,
        Integer promptTokens,
        Integer completionTokens,
        Instant createdAt
) {

    public static AdminAiChatMessageResponse from(AiChatMessage message) {
        return new AdminAiChatMessageResponse(
                message.getId(),
                message.getRole(),
                message.getContent(),
                message.getToolName(),
                message.getPromptTokens(),
                message.getCompletionTokens(),
                message.getCreatedAt()
        );
    }
}
