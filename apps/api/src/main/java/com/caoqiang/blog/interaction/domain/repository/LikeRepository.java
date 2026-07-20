package com.caoqiang.blog.interaction.domain.repository;

import com.caoqiang.blog.interaction.domain.model.Like;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 点赞 Repository
 * <p>
 * 提供点赞实体的数据库访问接口。位于数据访问层，继承 JPA 和 Specification 执行器。
 * </p>
 * <p>
 * 主要功能：
 * <ul>
 *   <li>点赞记录的 CRUD 操作</li>
 *   <li>检查用户是否已点赞</li>
 *   <li>按内容 ID 和用户 ID 查询点赞记录</li>
 *   <li>按用户 ID 查询点赞列表</li>
 *   <li>支持动态条件查询（通过 Specification）</li>
 *   <li>使用 EntityGraph 优化关联查询性能</li>
 * </ul>
 * </p>
 */
public interface LikeRepository extends JpaRepository<Like, UUID>, JpaSpecificationExecutor<Like> {

    /**
     * 根据动态条件查询点赞记录（分页）
     * <p>
     * 使用 EntityGraph 预加载 content 和 user 关联。
     * </p>
     *
     * @param specification 动态查询条件
     * @param pageable      分页参数
     * @return 点赞记录分页结果
     */
    @Override
    Page<Like> findAll(Specification<Like> specification, Pageable pageable);

    /**
     * 根据 ID 查询点赞记录
     *
     * @param id 点赞记录 ID
     * @return 点赞记录（可能为空）
     */
    @Override
    Optional<Like> findById(UUID id);

    /**
     * 检查用户是否已点赞指定内容
     *
     * @param contentId 内容 ID
     * @param userId    用户 ID
     * @return 如果已点赞返回 true
     */
    boolean existsByContentIdAndUserId(UUID contentId, UUID userId);

    /**
     * 原子创建点赞记录。并发请求命中唯一约束时返回 0，而不是抛出冲突异常。
     */
    @Modifying
    @Query(value = """
            insert into likes (id, content_id, user_id, created_at)
            values (:id, :contentId, :userId, now())
            on conflict do nothing
            """, nativeQuery = true)
    int insertIfAbsent(@Param("id") UUID id, @Param("contentId") UUID contentId, @Param("userId") UUID userId);

    /**
     * 原子删除点赞记录，返回实际删除行数。
     */
    @Modifying
    @Query("delete from Like l where l.contentId = :contentId and l.userId = :userId")
    int deleteByContentIdAndUserId(@Param("contentId") UUID contentId, @Param("userId") UUID userId);

    /**
     * 根据内容 ID 和用户 ID 查询点赞记录
     *
     * @param contentId 内容 ID
     * @param userId    用户 ID
     * @return 点赞记录（可能为空）
     */
    Optional<Like> findByContentIdAndUserId(UUID contentId, UUID userId);

    /**
     * 按用户 ID 查询点赞列表（分页）
     *
     * @param userId   用户 ID
     * @param pageable 分页参数
     * @return 点赞记录分页结果
     */
    Page<Like> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);
}
