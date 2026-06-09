package com.caoqiang.blog.interaction.application.service;

import com.caoqiang.blog.interaction.application.dto.CommentResponse;
import com.caoqiang.blog.interaction.application.dto.UserActivityResponse;
import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.model.Like;
import com.caoqiang.blog.interaction.domain.model.ViewRecord;
import com.caoqiang.blog.interaction.domain.repository.CommentRepository;
import com.caoqiang.blog.interaction.domain.repository.LikeRepository;
import com.caoqiang.blog.interaction.domain.repository.ViewRecordRepository;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.shared.util.PageUtils;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 互动查询服务（CQRS 读操作）
 * <p>
 * 处理博客内容互动的只读查询操作，包括评论列表和用户活动记录。
 * 遵循 CQRS 模式，与 {@link InteractionCommandService} 分离读写职责。
 * <p>
 * 核心职责：
 * <ul>
 *   <li>获取内容的评论列表（分页，支持登录用户查看自己的被屏蔽评论）</li>
 *   <li>获取当前用户的评论记录（分页）</li>
 *   <li>获取当前用户的点赞记录（分页）</li>
 *   <li>获取当前用户的浏览记录（分页）</li>
 * </ul>
 * <p>
 * 所有查询均使用 {@code @Transactional(readOnly = true)} 优化性能。
 */
@Service
public class InteractionQueryService {

    private static final int MAX_PAGE_SIZE = 50;

    private final CommentRepository commentRepository;
    private final LikeRepository likeRepository;
    private final ViewRecordRepository viewRecordRepository;

    public InteractionQueryService(
            CommentRepository commentRepository,
            LikeRepository likeRepository,
            ViewRecordRepository viewRecordRepository
    ) {
        this.commentRepository = commentRepository;
        this.likeRepository = likeRepository;
        this.viewRecordRepository = viewRecordRepository;
    }

    @Transactional(readOnly = true)
    public PageResponse<CommentResponse> comments(UUID contentId, int page, int size, UUID currentUserId) {
        Page<Comment> result;
        if (currentUserId == null) {
            result = commentRepository.findByContentIdAndStatusOrderByCreatedAtDesc(
                    contentId,
                    CommentStatus.VISIBLE,
                    pageRequest(page, size)
            );
        } else {
            Specification<Comment> spec = Specification
                    .<Comment>where((root, query, cb) -> cb.equal(root.get("content").get("id"), contentId))
                    .and((root, query, cb) -> cb.or(
                            cb.equal(root.get("status"), CommentStatus.VISIBLE),
                            cb.and(
                                    cb.equal(root.get("status"), CommentStatus.BLOCKED),
                                    cb.equal(root.get("user").get("id"), currentUserId)
                            )
                    ));
            result = commentRepository.findAll(spec, pageRequest(page, size));
        }
        return new PageResponse<>(
                result.getContent().stream()
                        .map(CommentResponse::from)
                        .toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    @Transactional(readOnly = true)
    public PageResponse<UserActivityResponse> myComments(AuthenticatedUser currentUser, int page, int size) {
        Page<Comment> result = commentRepository.findByUserIdOrderByCreatedAtDesc(currentUser.id(), pageRequest(page, size));
        return new PageResponse<>(
                result.getContent().stream()
                        .map(comment -> UserActivityResponse.comment(comment.getId(), comment.getContent(), comment.getCreatedAt()))
                        .toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    @Transactional(readOnly = true)
    public PageResponse<UserActivityResponse> myLikes(AuthenticatedUser currentUser, int page, int size) {
        Page<Like> result = likeRepository.findByUserIdOrderByCreatedAtDesc(currentUser.id(), pageRequest(page, size));
        return new PageResponse<>(
                result.getContent().stream()
                        .map(like -> UserActivityResponse.like(like.getContent(), like.getCreatedAt()))
                        .toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    @Transactional(readOnly = true)
    public PageResponse<UserActivityResponse> myViews(AuthenticatedUser currentUser, int page, int size) {
        Page<ViewRecord> result = viewRecordRepository.findByUserIdOrderByCreatedAtDesc(currentUser.id(), pageRequest(page, size));
        return new PageResponse<>(
                result.getContent().stream()
                        .map(view -> UserActivityResponse.view(view.getId(), view.getContent(), view.getCreatedAt()))
                        .toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    private PageRequest pageRequest(int page, int size) {
        return PageUtils.of(page, size, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "createdAt"));
    }
}
