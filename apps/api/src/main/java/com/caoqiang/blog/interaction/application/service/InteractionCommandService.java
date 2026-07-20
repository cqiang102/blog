package com.caoqiang.blog.interaction.application.service;

import com.caoqiang.blog.content.application.api.ContentInteractionService;
import com.caoqiang.blog.content.application.api.ContentInteractionSnapshot;
import com.caoqiang.blog.interaction.application.dto.CommentRequest;
import com.caoqiang.blog.interaction.application.dto.CommentResponse;
import com.caoqiang.blog.interaction.application.dto.LikeStateResponse;
import com.caoqiang.blog.interaction.application.dto.ViewStateResponse;
import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.model.ViewRecord;
import com.caoqiang.blog.interaction.domain.repository.CommentRepository;
import com.caoqiang.blog.interaction.domain.repository.LikeRepository;
import com.caoqiang.blog.interaction.domain.repository.ViewRecordRepository;
import com.caoqiang.blog.interaction.event.CommentCreatedEvent;
import com.caoqiang.blog.interaction.event.LikeAddedEvent;
import com.caoqiang.blog.interaction.event.LikeRemovedEvent;
import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 互动命令服务（CQRS 写操作）
 * <p>
 * 处理博客内容互动的写操作，包括评论、点赞和浏览记录。
 * 遵循 CQRS 模式，与 {@link InteractionQueryService} 分离读写职责。
 * <p>
 * 核心职责：
 * <ul>
 *   <li>评论的创建和删除</li>
 *   <li>内容的点赞和取消点赞</li>
 *   <li>浏览记录的创建</li>
 *   <li>发布领域事件（{@link CommentCreatedEvent}, {@link LikeAddedEvent}, {@link LikeRemovedEvent}）</li>
 * </ul>
 * <p>
 * 所有写操作均使用事务管理，确保数据一致性。
 */
@Service
public class InteractionCommandService {

    private static final Base64.Encoder BASE64_ENCODER = Base64.getUrlEncoder().withoutPadding();

    private final ContentInteractionService contentInteractionService;
    private final UserAccountService userAccountService;
    private final CommentRepository commentRepository;
    private final LikeRepository likeRepository;
    private final ViewRecordRepository viewRecordRepository;
    private final DomainEventPublisher domainEventPublisher;
    private final InteractionReferenceData referenceData;

    public InteractionCommandService(
            ContentInteractionService contentInteractionService,
            UserAccountService userAccountService,
            CommentRepository commentRepository,
            LikeRepository likeRepository,
            ViewRecordRepository viewRecordRepository,
            DomainEventPublisher domainEventPublisher,
            InteractionReferenceData referenceData) {
        this.contentInteractionService = contentInteractionService;
        this.userAccountService = userAccountService;
        this.commentRepository = commentRepository;
        this.likeRepository = likeRepository;
        this.viewRecordRepository = viewRecordRepository;
        this.domainEventPublisher = domainEventPublisher;
        this.referenceData = referenceData;
    }

    @Transactional
    public CommentResponse comment(AuthenticatedUser currentUser, UUID contentId, CommentRequest request) {
        ContentInteractionSnapshot content = publishedContent(contentId);
        IdentityUser user = activeUser(currentUser.id());
        String body = request.body().trim();
        if (body.isBlank()) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "评论内容不能为空");
        }
        Comment comment = commentRepository.save(new Comment(contentId, user.id(), body));
        contentInteractionService.incrementCommentCount(contentId, 1);
        domainEventPublisher.publishEvent(new CommentCreatedEvent(comment.getId(), contentId, currentUser.id()));
        return CommentResponse.from(comment, content, user, referenceData.avatarUrl(user));
    }

    @Transactional
    public void deleteComment(AuthenticatedUser currentUser, UUID commentId) {
        Comment comment = commentRepository
                .findByIdForUpdate(commentId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "评论不存在"));
        if (!comment.getUserId().equals(currentUser.id()) && currentUser.role() != Role.ADMIN) {
            throw new BusinessException(HttpStatus.FORBIDDEN, "只能删除自己的评论");
        }
        if (comment.getStatus() == CommentStatus.DELETED) {
            return;
        }
        if (comment.isVisible()) {
            contentInteractionService.incrementCommentCount(comment.getContentId(), -1);
        }
        comment.markDeleted();
    }

    @Transactional
    public LikeStateResponse like(AuthenticatedUser currentUser, UUID contentId) {
        ContentInteractionSnapshot content = publishedContent(contentId);
        activeUser(currentUser.id());
        int inserted = likeRepository.insertIfAbsent(UUID.randomUUID(), contentId, currentUser.id());
        if (inserted == 0) {
            return new LikeStateResponse(contentId, true, content.likeCount());
        }
        contentInteractionService.incrementLikeCount(contentId, 1);
        domainEventPublisher.publishEvent(new LikeAddedEvent(contentId, currentUser.id()));
        return new LikeStateResponse(contentId, true, content.likeCount() + 1);
    }

    @Transactional
    public LikeStateResponse unlike(AuthenticatedUser currentUser, UUID contentId) {
        ContentInteractionSnapshot content = publishedContent(contentId);
        int deleted = likeRepository.deleteByContentIdAndUserId(contentId, currentUser.id());
        if (deleted == 0) {
            return new LikeStateResponse(contentId, false, content.likeCount());
        }
        contentInteractionService.incrementLikeCount(contentId, -1);
        domainEventPublisher.publishEvent(new LikeRemovedEvent(contentId, currentUser.id()));
        return new LikeStateResponse(contentId, false, Math.max(0, content.likeCount() - 1));
    }

    @Transactional
    public ViewStateResponse recordView(
            AuthenticatedUser currentUser, UUID contentId, String clientIp, String userAgent) {
        ContentInteractionSnapshot content =
                contentInteractionService.findPublished(contentId).orElse(null);
        if (content == null) {
            return new ViewStateResponse(contentId, false, 0);
        }
        IdentityUser user = currentUser == null ? null : activeUser(currentUser.id());
        String anonymousId = generateAnonymousId(clientIp, userAgent);
        String ipHash = hashIp(clientIp);

        int inserted = viewRecordRepository.insertIfAbsent(
                UUID.randomUUID(), contentId, user != null ? user.id() : null, anonymousId, ipHash, userAgent);
        if (inserted == 0) {
            return new ViewStateResponse(contentId, true, content.viewCount());
        }
        contentInteractionService.incrementViewCount(contentId, 1);
        return new ViewStateResponse(contentId, true, content.viewCount() + 1);
    }

    @Transactional
    public void deleteMyLike(AuthenticatedUser currentUser, UUID contentId) {
        unlike(currentUser, contentId);
    }

    @Transactional
    public void deleteMyView(AuthenticatedUser currentUser, UUID viewRecordId) {
        ViewRecord viewRecord = viewRecordRepository
                .findByIdAndUserId(viewRecordId, currentUser.id())
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "浏览记录不存在"));
        if (viewRecordRepository.deleteByIdAndUserId(viewRecordId, currentUser.id()) == 1) {
            contentInteractionService.incrementViewCount(viewRecord.getContentId(), -1);
        }
    }

    private ContentInteractionSnapshot publishedContent(UUID contentId) {
        return contentInteractionService
                .findPublished(contentId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
    }

    private IdentityUser activeUser(UUID userId) {
        return userAccountService
                .findActiveById(userId)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }

    private String generateAnonymousId(String clientIp, String userAgent) {
        String raw = (clientIp != null ? clientIp : "unknown") + "|" + (userAgent != null ? userAgent : "unknown");
        return hashString(raw);
    }

    private String hashIp(String clientIp) {
        return hashString(clientIp != null ? clientIp : "unknown");
    }

    private String hashString(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return BASE64_ENCODER.encodeToString(hash);
        } catch (Exception e) {
            throw new IllegalStateException("Unable to hash", e);
        }
    }
}
