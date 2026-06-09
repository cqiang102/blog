package com.caoqiang.blog.ai.chat.application.dto;

import com.caoqiang.blog.ai.chat.domain.model.AiChatMessage;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.user.domain.model.User;
import java.time.Instant;
import java.util.UUID;

public record AdminAiChatSessionResponse(
        UUID id,
        UUID userId,
        String userNickname,
        String userEmail,
        String title,
        long messageCount,
        String lastMessage,
        Instant createdAt,
        Instant updatedAt
) {

    public static AdminAiChatSessionResponse from(
            AiChatSession session,
            long messageCount,
            AiChatMessage lastMessage
    ) {
        User user = session.getUser();
        return new AdminAiChatSessionResponse(
                session.getId(),
                user.getId(),
                user.getNickname(),
                user.getEmail(),
                session.getTitle(),
                messageCount,
                lastMessage == null ? null : lastMessage.getContent(),
                session.getCreatedAt(),
                session.getUpdatedAt()
        );
    }
}
