package com.caoqiang.blog.content.domain.repository;

import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.model.Tag;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.domain.Specification;

/**
 * 内容数据访问接口。
 * <p>
 * 继承 {@link JpaRepository} 提供基础 CRUD，继承 {@link JpaSpecificationExecutor} 支持动态条件查询。
 * <p>
 * 关键特性：
 * <ul>
 *   <li>推荐查询方法：按发布时间、点赞数排序，取 Top 10，通过 {@code @EntityGraph} 预加载 tags 和 coverMedia 避免 N+1</li>
 *   <li>详情查询：媒体集合在事务内单独加载，避免与 tags 联表产生笛卡尔重复</li>
 *   <li>计数原子更新：通过 {@code @Modifying} + JPQL 实现 likeCount / viewCount / commentCount 的原子增减</li>
 * </ul>
 */
public interface ContentRepository extends JpaRepository<Content, UUID>, JpaSpecificationExecutor<Content> {

    /**
     * 查询最新发布的 10 条内容（用于推荐列表的"最新"分组）。
     * 预加载 tags 和 coverMedia 以避免 N+1 查询。
     */
    @EntityGraph(attributePaths = {"tags", "coverMedia"})
    List<Content> findTop10ByStatusAndPublishedAtIsNotNullOrderByPublishedAtDesc(ContentStatus status);

    /**
     * 查询最热门的 10 条内容，按点赞数降序、发布时间降序排列（用于"最热"分组）。
     */
    @EntityGraph(attributePaths = {"tags", "coverMedia"})
    List<Content> findTop10ByStatusAndPublishedAtIsNotNullOrderByLikeCountDescPublishedAtDesc(ContentStatus status);

    /**
     * 查询置顶的 10 条内容，按发布时间降序排列（用于"置顶"分组）。
     */
    @EntityGraph(attributePaths = {"tags", "coverMedia"})
    List<Content> findTop10ByStatusAndPinnedTrueAndPublishedAtIsNotNullOrderByPublishedAtDesc(ContentStatus status);

    /**
     * 根据 ID 和状态查询内容详情，预加载 tags 和 coverMedia。
     * mediaAssets 保持懒加载，由详情服务在事务内单独查询，避免多集合联表时重复。
     *
     * @param id     内容 UUID
     * @param status 内容状态
     * @return 内容实体（若存在且状态匹配）
     */
    @EntityGraph(attributePaths = {"tags", "coverMedia"})
    Optional<Content> findByIdAndStatus(UUID id, ContentStatus status);

    /**
     * 根据 ID 查询未删除的内容，预加载 tags 和 coverMedia。
     *
     * @param id 内容 UUID
     * @return 内容实体（若存在且未被逻辑删除）
     */
    @EntityGraph(attributePaths = {"tags", "coverMedia"})
    Optional<Content> findByIdAndDeletedAtIsNull(UUID id);

    /**
     * 根据 ID 查询内容，预加载 tags 和 coverMedia。
     */
    @Override
    @EntityGraph(attributePaths = {"tags", "coverMedia"})
    Optional<Content> findById(UUID id);

    /**
     * 基于 Specification 的分页查询。
     * <p>
     * 注意：不使用 @EntityGraph，避免与 Specification 冲突导致 WHERE 条件丢失。
     * tags 和 coverMedia 通过 Hibernate.initialize() 在 Service 层事务内加载。
     */
    @Override
    Page<Content> findAll(Specification<Content> spec, Pageable pageable);

    /**
     * 检查 slug 是否已存在。
     *
     * @param slug URL 标识符
     * @return 是否存在
     */
    boolean existsBySlug(String slug);

    /**
     * 检查 slug 是否被其他内容占用（排除指定 ID）。
     *
     * @param slug URL 标识符
     * @param id   排除的内容 UUID
     * @return 是否存在冲突
     */
    boolean existsBySlugAndIdNot(String slug, UUID id);

    /**
     * 检查指定 ID 和状态的内容是否存在。
     *
     * @param id     内容 UUID
     * @param status 内容状态
     * @return 是否存在
     */
    boolean existsByIdAndStatus(UUID id, ContentStatus status);

    /**
     * 原子更新点赞数。
     * <p>
     * 使用 greatest 函数确保计数不会低于 0。delta 为正数表示增加，负数表示减少。
     *
     * @param contentId 内容 UUID
     * @param delta     变更量
     * @return 受影响的行数
     */
    @Modifying
    @Query("update Content c set c.likeCount = greatest(c.likeCount + :delta, 0) where c.id = :contentId")
    int incrementLikeCount(@Param("contentId") UUID contentId, @Param("delta") long delta);

    /**
     * 原子更新浏览数。
     *
     * @param contentId 内容 UUID
     * @param delta     变更量
     * @return 受影响的行数
     */
    @Modifying
    @Query("update Content c set c.viewCount = greatest(c.viewCount + :delta, 0) where c.id = :contentId")
    int incrementViewCount(@Param("contentId") UUID contentId, @Param("delta") long delta);

    /**
     * 原子更新评论数。
     *
     * @param contentId 内容 UUID
     * @param delta     变更量
     * @return 受影响的行数
     */
    @Modifying
    @Query("update Content c set c.commentCount = greatest(c.commentCount + :delta, 0) where c.id = :contentId")
    int incrementCommentCount(@Param("contentId") UUID contentId, @Param("delta") long delta);
}
