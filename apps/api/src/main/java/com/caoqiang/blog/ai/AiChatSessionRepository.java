package com.caoqiang.blog.ai;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

/**
 * AI 聊天会话 Repository。
 * <p>
 * 提供会话实体的 CRUD 操作，支持按用户 ID 进行各种查询。
 * 同时实现 {@link JpaSpecificationExecutor} 以支持动态条件查询（管理端筛选）。
 */
public interface AiChatSessionRepository extends JpaRepository<AiChatSession, UUID>,
        JpaSpecificationExecutor<AiChatSession> {

    /**
     * 根据会话 ID 和用户 ID 查找会话（确保用户只能访问自己的会话）。
     *
     * @param id     会话 ID
     * @param userId 用户 ID
     * @return 匹配的会话
     */
    Optional<AiChatSession> findByIdAndUserId(UUID id, UUID userId);

    /**
     * 获取指定用户最近更新的 20 个会话。
     *
     * @param userId 用户 ID
     * @return 按更新时间倒序排列的会话列表
     */
    List<AiChatSession> findTop20ByUserIdOrderByUpdatedAtDesc(UUID userId);

    /**
     * 获取指定用户最近更新的一个会话。
     *
     * @param userId 用户 ID
     * @return 最近的会话
     */
    Optional<AiChatSession> findFirstByUserIdOrderByUpdatedAtDesc(UUID userId);
}
