package com.caoqiang.blog.ai;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AiChatMessageRepository extends JpaRepository<AiChatMessage, UUID> {

    long countBySessionId(UUID sessionId);

    List<AiChatMessage> findBySessionIdOrderByCreatedAtAsc(UUID sessionId);

    Optional<AiChatMessage> findFirstBySessionIdOrderByCreatedAtDesc(UUID sessionId);
}
