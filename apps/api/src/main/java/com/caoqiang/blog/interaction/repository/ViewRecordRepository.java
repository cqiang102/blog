package com.caoqiang.blog.interaction.repository;

import com.caoqiang.blog.interaction.entity.Comment;
import com.caoqiang.blog.interaction.entity.CommentStatus;
import com.caoqiang.blog.interaction.entity.Like;
import com.caoqiang.blog.interaction.entity.ViewRecord;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.domain.Specification;

/**
 * 浏览记录 Repository
 * <p>
 * 提供浏览记录实体的数据库访问接口。位于数据访问层，继承 JPA 和 Specification 执行器。
 * </p>
 * <p>
 * 主要功能：
 * <ul>
 *   <li>浏览记录的 CRUD 操作</li>
 *   <li>检查用户是否已浏览（支持已登录和匿名用户）</li>
 *   <li>按用户 ID 查询浏览记录列表</li>
 *   <li>支持动态条件查询（通过 Specification）</li>
 *   <li>使用 EntityGraph 优化关联查询性能</li>
 * </ul>
 * </p>
 */
public interface ViewRecordRepository extends JpaRepository<ViewRecord, UUID>, JpaSpecificationExecutor<ViewRecord> {

    /**
     * 根据动态条件查询浏览记录（分页）
     * <p>
     * 使用 EntityGraph 预加载 content 和 user 关联。
     * </p>
     *
     * @param specification 动态查询条件
     * @param pageable      分页参数
     * @return 浏览记录分页结果
     */
    @Override
    @EntityGraph(attributePaths = {"content", "user"})
    Page<ViewRecord> findAll(Specification<ViewRecord> specification, Pageable pageable);

    /**
     * 根据 ID 查询浏览记录
     *
     * @param id 浏览记录 ID
     * @return 浏览记录（可能为空）
     */
    @Override
    @EntityGraph(attributePaths = {"content", "user"})
    Optional<ViewRecord> findById(UUID id);

    /**
     * 按用户 ID 查询浏览记录列表（分页）
     *
     * @param userId   用户 ID
     * @param pageable 分页参数
     * @return 浏览记录分页结果
     */
    Page<ViewRecord> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    /**
     * 根据浏览记录 ID 和用户 ID 查询
     * <p>
     * 用于验证浏览记录所有权。
     * </p>
     *
     * @param id     浏览记录 ID
     * @param userId 用户 ID
     * @return 浏览记录（可能为空）
     */
    Optional<ViewRecord> findByIdAndUserId(UUID id, UUID userId);

    /**
     * 检查匿名用户是否已浏览指定内容
     *
     * @param contentId   内容 ID
     * @param anonymousId 匿名用户 ID
     * @return 如果已浏览返回 true
     */
    boolean existsByContentIdAndAnonymousId(UUID contentId, String anonymousId);

    /**
     * 检查已登录用户是否已浏览指定内容
     *
     * @param contentId 内容 ID
     * @param userId    用户 ID
     * @return 如果已浏览返回 true
     */
    boolean existsByContentIdAndUserId(UUID contentId, UUID userId);
}
