package com.caoqiang.blog.interaction.application.service;

import com.caoqiang.blog.interaction.application.dto.CommentRequest;
import com.caoqiang.blog.interaction.application.dto.CommentResponse;
import com.caoqiang.blog.interaction.application.dto.LikeStateResponse;
import com.caoqiang.blog.interaction.application.dto.ViewStateResponse;
import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.model.Like;
import com.caoqiang.blog.interaction.domain.model.ViewRecord;
import com.caoqiang.blog.interaction.domain.repository.CommentRepository;
import com.caoqiang.blog.interaction.domain.repository.LikeRepository;
import com.caoqiang.blog.interaction.domain.repository.ViewRecordRepository;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import com.caoqiang.blog.shared.domain.event.interaction.CommentCreatedEvent;
import com.caoqiang.blog.shared.domain.event.interaction.LikeAddedEvent;
import com.caoqiang.blog.shared.domain.event.interaction.LikeRemovedEvent;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.repository.UserRepository;
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

    private final ContentRepository contentRepository;
    private final UserRepository userRepository;
    private final CommentRepository commentRepository;
    private final LikeRepository likeRepository;
    private final ViewRecordRepository viewRecordRepository;
    private final CommentAuditService commentAuditService;
    private final DomainEventPublisher domainEventPublisher;

    public InteractionCommandService(
            ContentRepository contentRepository,
            UserRepository userRepository,
            CommentRepository commentRepository,
            LikeRepository likeRepository,
            ViewRecordRepository viewRecordRepository,
            CommentAuditService commentAuditService,
            DomainEventPublisher domainEventPublisher
    ) {
        this.contentRepository = contentRepository;
        this.userRepository = userRepository;
        this.commentRepository = commentRepository;
        this.likeRepository = likeRepository;
        this.viewRecordRepository = viewRecordRepository;
        this.commentAuditService = commentAuditService;
        this.domainEventPublisher = domainEventPublisher;
    }

    @Transactional
    public CommentResponse comment(AuthenticatedUser currentUser, UUID contentId, CommentRequest request) {
        Content content = publishedContent(contentId);
        User user = activeUser(currentUser.id());
        Comment comment = commentRepository.save(new Comment(content, user, request.body().trim()));
        contentRepository.incrementCommentCount(contentId, 1);
        commentAuditService.audit(comment.getId());
        domainEventPublisher.publishEvent(new CommentCreatedEvent(comment.getId(), contentId, currentUser.id()));
        return CommentResponse.from(comment);
    }

    @Transactional
    public void deleteComment(AuthenticatedUser currentUser, UUID commentId) {
        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "评论不存在"));
        if (!comment.getUser().getId().equals(currentUser.id()) && currentUser.role() != Role.ADMIN) {
            throw new BusinessException(HttpStatus.FORBIDDEN, "只能删除自己的评论");
        }
        if (comment.getStatus() == CommentStatus.DELETED) {
            return;
        }
        if (comment.isVisible()) {
            contentRepository.incrementCommentCount(comment.getContent().getId(), -1);
        }
        comment.markDeleted();
    }

    @Transactional
    public LikeStateResponse like(AuthenticatedUser currentUser, UUID contentId) {
        Content content = publishedContent(contentId);
        User user = activeUser(currentUser.id());
        if (likeRepository.existsByContentIdAndUserId(contentId, currentUser.id())) {
            return new LikeStateResponse(contentId, true, content.getLikeCount());
        }
        likeRepository.save(new Like(content, user));
        contentRepository.incrementLikeCount(contentId, 1);
        domainEventPublisher.publishEvent(new LikeAddedEvent(contentId, currentUser.id()));
        return new LikeStateResponse(contentId, true, content.getLikeCount() + 1);
    }

    @Transactional
    public LikeStateResponse unlike(AuthenticatedUser currentUser, UUID contentId) {
        Content content = publishedContent(contentId);
        return likeRepository.findByContentIdAndUserId(contentId, currentUser.id())
                .map(like -> {
                    likeRepository.delete(like);
                    contentRepository.incrementLikeCount(contentId, -1);
                    domainEventPublisher.publishEvent(new LikeRemovedEvent(contentId, currentUser.id()));
                    return new LikeStateResponse(contentId, false, Math.max(0, content.getLikeCount() - 1));
                })
                .orElseGet(() -> new LikeStateResponse(contentId, false, content.getLikeCount()));
    }

    @Transactional
    public ViewStateResponse recordView(AuthenticatedUser currentUser, UUID contentId, String clientIp, String userAgent) {
        Content content = publishedContent(contentId);
        User user = currentUser == null ? null : activeUser(currentUser.id());
        String anonymousId = generateAnonymousId(clientIp, userAgent);
        String ipHash = hashIp(clientIp);

        if (user != null) {
            if (viewRecordRepository.existsByContentIdAndUserId(contentId, user.getId())) {
                return new ViewStateResponse(contentId, true, content.getViewCount());
            }
        } else {
            if (viewRecordRepository.existsByContentIdAndAnonymousId(contentId, anonymousId)) {
                return new ViewStateResponse(contentId, true, content.getViewCount());
            }
        }

        viewRecordRepository.save(new ViewRecord(content, user, anonymousId, ipHash, userAgent));
        contentRepository.incrementViewCount(contentId, 1);
        return new ViewStateResponse(contentId, true, content.getViewCount() + 1);
    }

    @Transactional
    public void deleteMyLike(AuthenticatedUser currentUser, UUID contentId) {
        unlike(currentUser, contentId);
    }

    @Transactional
    public void deleteMyView(AuthenticatedUser currentUser, UUID viewRecordId) {
        ViewRecord viewRecord = viewRecordRepository.findByIdAndUserId(viewRecordId, currentUser.id())
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "浏览记录不存在"));
        viewRecordRepository.delete(viewRecord);
        contentRepository.incrementViewCount(viewRecord.getContent().getId(), -1);
    }

    private Content publishedContent(UUID contentId) {
        return contentRepository.findByIdAndStatus(contentId, ContentStatus.PUBLISHED)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
    }

    private User activeUser(UUID userId) {
        return userRepository.findById(userId)
                .filter(User::isActive)
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
