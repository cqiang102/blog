package com.caoqiang.blog.ai;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface AiChatSessionRepository extends JpaRepository<AiChatSession, UUID>,
        JpaSpecificationExecutor<AiChatSession> {

    Optional<AiChatSession> findByIdAndUserId(UUID id, UUID userId);
}
