package com.caoqiang.blog.ai;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * AI 聊天消息 Repository。
 * <p>
 * 提供消息实体的 CRUD 操作，支持按会话 ID 查询消息列表、统计消息数等。
 */
public interface AiChatMessageRepository extends JpaRepository<AiChatMessage, UUID> {

    /**
     * 统计指定会话的消息数量。
     *
     * @param sessionId 会话 ID
     * @return 消息数量
     */
    long countBySessionId(UUID sessionId);

    /**
     * 获取指定会话的所有消息，按创建时间正序排列。
     *
     * @param sessionId 会话 ID
     * @return 消息列表
     */
    List<AiChatMessage> findBySessionIdOrderByCreatedAtAsc(UUID sessionId);

    /**
     * 分页获取指定会话的消息，按创建时间正序排列。
     *
     * @param sessionId 会话 ID
     * @param pageable  分页参数
     * @return 分页消息列表
     */
    Page<AiChatMessage> findBySessionIdOrderByCreatedAtAsc(UUID sessionId, Pageable pageable);

    /**
     * 获取指定会话的最后一条消息。
     *
     * @param sessionId 会话 ID
     * @return 最后一条消息
     */
    Optional<AiChatMessage> findFirstBySessionIdOrderByCreatedAtDesc(UUID sessionId);
}
