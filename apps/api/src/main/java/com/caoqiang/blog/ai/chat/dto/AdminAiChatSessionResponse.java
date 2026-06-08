package com.caoqiang.blog.ai.chat.dto;

import com.caoqiang.blog.ai.chat.entity.AiChatMessage;
import com.caoqiang.blog.ai.chat.entity.AiChatSession;
import com.caoqiang.blog.user.entity.User;
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
