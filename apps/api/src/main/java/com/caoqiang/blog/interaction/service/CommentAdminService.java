package com.caoqiang.blog.interaction.service;

import com.caoqiang.blog.interaction.dto.AdminCommentResponse;
import com.caoqiang.blog.interaction.dto.AdminCommentStatusRequest;
import com.caoqiang.blog.interaction.dto.AdminLikeResponse;
import com.caoqiang.blog.interaction.dto.AdminViewRecordResponse;
import com.caoqiang.blog.interaction.dto.CommentRequest;
import com.caoqiang.blog.interaction.dto.CommentResponse;
import com.caoqiang.blog.interaction.dto.LikeStateResponse;
import com.caoqiang.blog.interaction.dto.UserActivityResponse;
import com.caoqiang.blog.interaction.dto.ViewStateResponse;
import com.caoqiang.blog.interaction.entity.Comment;
import com.caoqiang.blog.interaction.entity.CommentStatus;
import com.caoqiang.blog.interaction.entity.Like;
import com.caoqiang.blog.interaction.entity.ViewRecord;
import com.caoqiang.blog.interaction.repository.CommentRepository;
import com.caoqiang.blog.interaction.repository.LikeRepository;
import com.caoqiang.blog.interaction.repository.ViewRecordRepository;

import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.content.repository.ContentRepository;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 管理端评论服务
 * <p>
 * 提供管理员对评论的查询、状态修改和删除功能。
 * 位于服务层，被管理端控制器调用，支持多条件过滤和状态管理。
 * </p>
 * <p>
 * 主要功能：
 * <ul>
 *   <li>评论列表查询（支持按状态、内容 ID、用户 ID 过滤）</li>
 *   <li>评论状态修改（VISIBLE/PENDING/BLOCKED/DELETED）</li>
 *   <li>评论删除（软删除，标记为 DELETED 状态）</li>
 *   <li>自动同步内容的评论计数</li>
 * </ul>
 * </p>
 */
@Service
public class CommentAdminService {

    /** 最大分页大小限制 */
    private static final int MAX_PAGE_SIZE = 100;

    /** 评论仓储 */
    private final CommentRepository commentRepository;
    /** 内容仓储（用于更新评论计数） */
    private final ContentRepository contentRepository;

    /**
     * 构造函数，注入依赖的仓储
     *
     * @param commentRepository 评论仓储
     * @param contentRepository 内容仓储
     */
    public CommentAdminService(CommentRepository commentRepository, ContentRepository contentRepository) {
        this.commentRepository = commentRepository;
        this.contentRepository = contentRepository;
    }

    /**
     * 查询评论列表（分页）
     * <p>
     * 支持按状态、内容 ID 和用户 ID 进行多条件过滤。
     * </p>
     *
     * @param page      页码
     * @param size      每页大小
     * @param status    评论状态（可选过滤条件）
     * @param contentId 内容 ID（可选过滤条件）
     * @param userId    用户 ID（可选过滤条件）
     * @return 评论响应的分页结果
     */
    @Transactional(readOnly = true)
    public PageResponse<AdminCommentResponse> list(
            int page,
            int size,
            CommentStatus status,
            UUID contentId,
            UUID userId
    ) {
        Page<Comment> result = commentRepository.findAll(
                filters(status, contentId, userId),
                pageRequest(page, size)
        );
        return new PageResponse<>(
                result.getContent().stream().map(AdminCommentResponse::from).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    /**
     * 设置评论状态
     * <p>
     * 修改评论状态并自动同步内容的评论计数。
     * 例如：从 VISIBLE 改为 BLOCKED 会减少评论计数，从 BLOCKED 改为 VISIBLE 会增加计数。
     * </p>
     *
     * @param id           评论 ID
     * @param targetStatus 目标状态
     * @return 更新后的评论响应
     */
    @Transactional
    public AdminCommentResponse setStatus(UUID id, CommentStatus targetStatus) {
        Comment comment = commentRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "评论不存在"));
        CommentStatus previousStatus = comment.getStatus();
        // 只有状态发生变化时才更新
        if (previousStatus != targetStatus) {
            comment.setStatus(targetStatus);
            // 同步评论计数
            syncCommentCount(comment, previousStatus, targetStatus);
        }
        return AdminCommentResponse.from(comment);
    }

    /**
     * 删除评论（软删除）
     * <p>
     * 将评论状态设置为 DELETED，不会物理删除数据。
     * </p>
     *
     * @param id 评论 ID
     */
    @Transactional
    public void delete(UUID id) {
        setStatus(id, CommentStatus.DELETED);
    }

    /**
     * 构建动态过滤条件
     * <p>
     * 使用 JPA Specification 实现多条件动态查询。
     * </p>
     *
     * @param status    评论状态（可选）
     * @param contentId 内容 ID（可选）
     * @param userId    用户 ID（可选）
     * @return Specification 过滤条件
     */
    private Specification<Comment> filters(CommentStatus status, UUID contentId, UUID userId) {
        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (status != null) {
                predicates.add(criteriaBuilder.equal(root.get("status"), status));
            }
            if (contentId != null) {
                predicates.add(criteriaBuilder.equal(root.get("content").get("id"), contentId));
            }
            if (userId != null) {
                predicates.add(criteriaBuilder.equal(root.get("user").get("id"), userId));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }

    /**
     * 同步内容的评论计数
     * <p>
     * 当评论状态在 VISIBLE 和非 VISIBLE 之间切换时，自动调整内容的评论计数。
     * </p>
     *
     * @param comment        评论实体
     * @param previousStatus 原状态
     * @param targetStatus   目标状态
     */
    private void syncCommentCount(Comment comment, CommentStatus previousStatus, CommentStatus targetStatus) {
        if (previousStatus == CommentStatus.VISIBLE && targetStatus != CommentStatus.VISIBLE) {
            // 从可见变为不可见，减少计数
            contentRepository.incrementCommentCount(comment.getContent().getId(), -1);
        } else if (previousStatus != CommentStatus.VISIBLE && targetStatus == CommentStatus.VISIBLE) {
            // 从不可见变为可见，增加计数
            contentRepository.incrementCommentCount(comment.getContent().getId(), 1);
        }
    }

    /**
     * 创建分页请求对象
     *
     * @param page 页码
     * @param size 每页大小
     * @return 分页请求对象
     */
    private PageRequest pageRequest(int page, int size) {
        return PageRequest.of(
                Math.max(0, page),
                Math.max(1, Math.min(size, MAX_PAGE_SIZE)),
                Sort.by(Sort.Direction.DESC, "createdAt")
        );
    }
}
