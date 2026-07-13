package com.caoqiang.blog.interaction.application.service;

import com.caoqiang.blog.content.application.api.ContentInteractionService;
import com.caoqiang.blog.content.application.api.ContentInteractionSnapshot;
import com.caoqiang.blog.interaction.application.dto.AdminCommentResponse;
import com.caoqiang.blog.interaction.application.dto.AdminCommentStatusRequest;
import com.caoqiang.blog.interaction.application.dto.AdminLikeResponse;
import com.caoqiang.blog.interaction.application.dto.AdminViewRecordResponse;
import com.caoqiang.blog.interaction.application.dto.CommentRequest;
import com.caoqiang.blog.interaction.application.dto.CommentResponse;
import com.caoqiang.blog.interaction.application.dto.LikeStateResponse;
import com.caoqiang.blog.interaction.application.dto.UserActivityResponse;
import com.caoqiang.blog.interaction.application.dto.ViewStateResponse;
import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.model.Like;
import com.caoqiang.blog.interaction.domain.model.ViewRecord;
import com.caoqiang.blog.interaction.domain.repository.CommentRepository;
import com.caoqiang.blog.interaction.domain.repository.LikeRepository;
import com.caoqiang.blog.interaction.domain.repository.ViewRecordRepository;

import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import com.caoqiang.blog.interaction.event.LikeRemovedEvent;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 管理端互动查询服务
 * <p>
 * 提供管理员对点赞和浏览记录的查询、删除功能。
 * 位于服务层，被管理端控制器调用，支持按内容 ID 和用户 ID 进行过滤。
 * </p>
 * <p>
 * 主要功能：
 * <ul>
 *   <li>点赞记录的查询和删除</li>
 *   <li>浏览记录的查询和删除</li>
 *   <li>支持多条件动态过滤</li>
 * </ul>
 * </p>
 */
@Service
public class InteractionAdminService {

    /** 最大分页大小限制 */
    private static final int MAX_PAGE_SIZE = 100;

    /** 点赞仓储 */
    private final LikeRepository likeRepository;
    /** 浏览记录仓储 */
    private final ViewRecordRepository viewRecordRepository;
    /** 内容仓储（用于更新计数） */
    private final ContentInteractionService contentInteractionService;
    private final DomainEventPublisher domainEventPublisher;
    private final InteractionReferenceData referenceData;

    /**
     * 构造函数，注入依赖的仓储
     *
     * @param likeRepository       点赞仓储
     * @param viewRecordRepository 浏览记录仓储
     * @param contentRepository    内容仓储
     */
    public InteractionAdminService(
            LikeRepository likeRepository,
            ViewRecordRepository viewRecordRepository,
            ContentInteractionService contentInteractionService,
            DomainEventPublisher domainEventPublisher,
            InteractionReferenceData referenceData
    ) {
        this.likeRepository = likeRepository;
        this.viewRecordRepository = viewRecordRepository;
        this.contentInteractionService = contentInteractionService;
        this.domainEventPublisher = domainEventPublisher;
        this.referenceData = referenceData;
    }

    /**
     * 查询点赞记录（分页）
     * <p>
     * 支持按内容 ID 和用户 ID 进行过滤。
     * </p>
     *
     * @param page      页码
     * @param size      每页大小
     * @param contentId 内容 ID（可选过滤条件）
     * @param userId    用户 ID（可选过滤条件）
     * @return 点赞响应的分页结果
     */
    @Transactional(readOnly = true)
    public PageResponse<AdminLikeResponse> likes(int page, int size, UUID contentId, UUID userId) {
        Page<Like> result = likeRepository.findAll(
                filters(contentId, userId),
                pageRequest(page, size)
        );
        Map<UUID, ContentInteractionSnapshot> contents = referenceData.contents(
                result.getContent().stream().map(Like::getContentId).toList()
        );
        var users = referenceData.users(result.getContent().stream().map(Like::getUserId).toList());
        return new PageResponse<>(
                result.getContent().stream().map(like -> AdminLikeResponse.from(
                        like,
                        referenceData.content(contents, like.getContentId()),
                        referenceData.user(users, like.getUserId())
                )).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    /**
     * 删除点赞记录
     * <p>
     * 删除后会同步减少内容的点赞计数。
     * </p>
     *
     * @param id 点赞记录 ID
     */
    @Transactional
    public void deleteLike(UUID id) {
        Like like = likeRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "点赞记录不存在"));
        likeRepository.delete(like);
        contentInteractionService.incrementLikeCount(like.getContentId(), -1);
        domainEventPublisher.publishEvent(new LikeRemovedEvent(
                like.getContentId(),
                like.getUserId()
        ));
    }

    /**
     * 查询浏览记录（分页）
     * <p>
     * 支持按内容 ID 和用户 ID 进行过滤。
     * </p>
     *
     * @param page      页码
     * @param size      每页大小
     * @param contentId 内容 ID（可选过滤条件）
     * @param userId    用户 ID（可选过滤条件）
     * @return 浏览记录响应的分页结果
     */
    @Transactional(readOnly = true)
    public PageResponse<AdminViewRecordResponse> views(int page, int size, UUID contentId, UUID userId) {
        Page<ViewRecord> result = viewRecordRepository.findAll(
                filters(contentId, userId),
                pageRequest(page, size)
        );
        Map<UUID, ContentInteractionSnapshot> contents = referenceData.contents(
                result.getContent().stream().map(ViewRecord::getContentId).toList()
        );
        var users = referenceData.users(result.getContent().stream()
                .map(ViewRecord::getUserId).filter(java.util.Objects::nonNull).toList());
        return new PageResponse<>(
                result.getContent().stream().map(view -> AdminViewRecordResponse.from(
                        view,
                        referenceData.content(contents, view.getContentId()),
                        view.getUserId() == null ? null : referenceData.user(users, view.getUserId())
                )).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    /**
     * 删除浏览记录
     * <p>
     * 删除后会同步减少内容的浏览计数。
     * </p>
     *
     * @param id 浏览记录 ID
     */
    @Transactional
    public void deleteView(UUID id) {
        ViewRecord viewRecord = viewRecordRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "浏览记录不存在"));
        viewRecordRepository.delete(viewRecord);
        contentInteractionService.incrementViewCount(viewRecord.getContentId(), -1);
    }

    /**
     * 构建动态过滤条件
     * <p>
     * 使用 JPA Specification 实现多条件动态查询。
     * </p>
     *
     * @param <T>       实体类型
     * @param contentId 内容 ID（可选）
     * @param userId    用户 ID（可选）
     * @return Specification 过滤条件
     */
    private <T> Specification<T> filters(UUID contentId, UUID userId) {
        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (contentId != null) {
                predicates.add(criteriaBuilder.equal(root.get("contentId"), contentId));
            }
            if (userId != null) {
                predicates.add(criteriaBuilder.equal(root.get("userId"), userId));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
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
