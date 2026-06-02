package com.caoqiang.blog.ai;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AiChatSessionRepository extends JpaRepository<AiChatSession, UUID> {

    Optional<AiChatSession> findByIdAndUserId(UUID id, UUID userId);
}
