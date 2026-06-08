package com.caoqiang.blog.ai;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

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
     * 根据会话 ID 和用户 ID 查找未删除的会话。
     *
     * @param id     会话 ID
     * @param userId 用户 ID
     * @return 匹配的未删除会话
     */
    Optional<AiChatSession> findByIdAndUserIdAndDeletedFalse(UUID id, UUID userId);

    /**
     * 获取指定用户最近更新的 20 个会话。
     *
     * @param userId 用户 ID
     * @return 按更新时间倒序排列的会话列表
     */
    List<AiChatSession> findTop20ByUserIdOrderByUpdatedAtDesc(UUID userId);

    /**
     * 获取指定用户最近更新的 20 个会话及其消息数（避免 N+1 查询）。
     * 只返回未删除的会话和消息。
     *
     * @param userId 用户 ID
     * @return 包含会话和消息数的 Object 数组列表，每个数组 [0]=AiChatSession, [1]=Long(messageCount)
     */
    @Query("""
            SELECT s, COUNT(m) 
            FROM AiChatSession s 
            LEFT JOIN AiChatMessage m ON m.session.id = s.id AND m.deleted = false
            WHERE s.user.id = :userId AND s.deleted = false
            GROUP BY s 
            ORDER BY s.updatedAt DESC 
            LIMIT 20
            """)
    List<Object[]> findTop20WithMessageCount(@Param("userId") UUID userId);

    /**
     * 获取指定用户最近更新的一个未删除会话。
     *
     * @param userId 用户 ID
     * @return 最近的未删除会话
     */
    Optional<AiChatSession> findFirstByUserIdAndDeletedFalseOrderByUpdatedAtDesc(UUID userId);

    /**
     * 统计指定用户的未删除会话数量。
     *
     * @param userId 用户 ID
     * @return 未删除会话数量
     */
    long countByUserIdAndDeletedFalse(UUID userId);
}
