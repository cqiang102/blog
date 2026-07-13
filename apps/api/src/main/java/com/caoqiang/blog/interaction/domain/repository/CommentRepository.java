package com.caoqiang.blog.interaction.domain.repository;

import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.repository.query.Param;

/**
 * 评论 Repository
 * <p>
 * 提供评论实体的数据库访问接口。位于数据访问层，继承 JPA 和 Specification 执行器。
 * </p>
 * <p>
 * 主要功能：
 * <ul>
 *   <li>评论的 CRUD 操作</li>
 *   <li>按内容 ID 和状态查询评论</li>
 *   <li>按用户 ID 查询评论</li>
 *   <li>支持动态条件查询（通过 Specification）</li>
 *   <li>使用 EntityGraph 优化关联查询性能</li>
 * </ul>
 * </p>
 */
public interface CommentRepository extends JpaRepository<Comment, UUID>, JpaSpecificationExecutor<Comment> {

    /**
     * 根据动态条件查询评论（分页）
     * <p>
     * 使用 EntityGraph 预加载 content 和 user 关联，避免 N+1 查询问题。
     * </p>
     *
     * @param specification 动态查询条件
     * @param pageable      分页参数
     * @return 评论分页结果
     */
    @Override
    Page<Comment> findAll(Specification<Comment> specification, Pageable pageable);

    /**
     * 根据 ID 查询评论
     * <p>
     * 使用 EntityGraph 预加载 content 和 user 关联。
     * </p>
     *
     * @param id 评论 ID
     * @return 评论实体（可能为空）
     */
    @Override
    Optional<Comment> findById(UUID id);

    /**
     * 锁定评论后再修改状态，避免审核、删除和人工操作重复调整内容计数。
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from Comment c where c.id = :id")
    Optional<Comment> findByIdForUpdate(@Param("id") UUID id);

    /**
     * 按内容 ID 和单一状态查询评论（分页）
     *
     * @param contentId 内容 ID
     * @param status    评论状态
     * @param pageable  分页参数
     * @return 评论分页结果
     */
    Page<Comment> findByContentIdAndStatusOrderByCreatedAtDesc(UUID contentId, CommentStatus status, Pageable pageable);

    /**
     * 按内容 ID 和多个状态查询评论（分页）
     *
     * @param contentId 内容 ID
     * @param statuses  评论状态列表
     * @param pageable  分页参数
     * @return 评论分页结果
     */
    Page<Comment> findByContentIdAndStatusInOrderByCreatedAtDesc(UUID contentId, List<CommentStatus> statuses, Pageable pageable);

    /**
     * 按用户 ID 查询评论（分页）
     *
     * @param userId   用户 ID
     * @param pageable 分页参数
     * @return 评论分页结果
     */
    Page<Comment> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    /**
     * 根据评论 ID 和用户 ID 查询评论
     * <p>
     * 用于验证评论所有权。
     * </p>
     *
     * @param id     评论 ID
     * @param userId 用户 ID
     * @return 评论实体（可能为空）
     */
    Optional<Comment> findByIdAndUserId(UUID id, UUID userId);
}
