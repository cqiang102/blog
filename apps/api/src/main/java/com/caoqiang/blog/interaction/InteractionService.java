package com.caoqiang.blog.interaction;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.auth.Role;
import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.content.Content;
import com.caoqiang.blog.content.ContentRepository;
import com.caoqiang.blog.content.ContentStatus;
import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class InteractionService {

    private static final int MAX_PAGE_SIZE = 50;
    private static final Base64.Encoder BASE64_ENCODER = Base64.getUrlEncoder().withoutPadding();

    private final ContentRepository contentRepository;
    private final UserRepository userRepository;
    private final CommentRepository commentRepository;
    private final LikeRepository likeRepository;
    private final ViewRecordRepository viewRecordRepository;
    private final CommentAuditService commentAuditService;

    public InteractionService(
            ContentRepository contentRepository,
            UserRepository userRepository,
            CommentRepository commentRepository,
            LikeRepository likeRepository,
            ViewRecordRepository viewRecordRepository,
            CommentAuditService commentAuditService
    ) {
        this.contentRepository = contentRepository;
        this.userRepository = userRepository;
        this.commentRepository = commentRepository;
        this.likeRepository = likeRepository;
        this.viewRecordRepository = viewRecordRepository;
        this.commentAuditService = commentAuditService;
    }

    @Transactional(readOnly = true)
    public PageResponse<CommentResponse> comments(UUID contentId, int page, int size, UUID currentUserId) {
        List<CommentStatus> statuses = List.of(CommentStatus.VISIBLE, CommentStatus.BLOCKED);
        Page<Comment> result = commentRepository.findByContentIdAndStatusInOrderByCreatedAtDesc(
                contentId,
                statuses,
                pageRequest(page, size)
        );
        return new PageResponse<>(
                result.getContent().stream()
                        .filter(c -> c.isVisible() || (currentUserId != null && c.getUser().getId().equals(currentUserId)))
                        .map(CommentResponse::from)
                        .toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    @Transactional
    public CommentResponse comment(AuthenticatedUser currentUser, UUID contentId, CommentRequest request) {
        Content content = publishedContent(contentId);
        User user = activeUser(currentUser.id());
        Comment comment = commentRepository.save(new Comment(content, user, request.body().trim()));
        contentRepository.incrementCommentCount(contentId, 1);

        commentAuditService.audit(comment.getId());

        return CommentResponse.from(comment);
    }

    @Transactional
    public void deleteComment(AuthenticatedUser currentUser, UUID commentId) {
        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "评论不存在"));
        if (!comment.getUser().getId().equals(currentUser.id()) && currentUser.role() != Role.ADMIN) {
            throw new BusinessException(HttpStatus.FORBIDDEN, "只能删除自己的评论");
        }
        if (comment.isVisible()) {
            comment.markDeleted();
            contentRepository.incrementCommentCount(comment.getContent().getId(), -1);
        }
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
        return new LikeStateResponse(contentId, true, content.getLikeCount() + 1);
    }

    @Transactional
    public LikeStateResponse unlike(AuthenticatedUser currentUser, UUID contentId) {
        Content content = publishedContent(contentId);
        return likeRepository.findByContentIdAndUserId(contentId, currentUser.id())
                .map(like -> {
                    likeRepository.delete(like);
                    contentRepository.incrementLikeCount(contentId, -1);
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

    private PageRequest pageRequest(int page, int size) {
        return PageRequest.of(
                Math.max(0, page),
                Math.max(1, Math.min(size, MAX_PAGE_SIZE)),
                Sort.by(Sort.Direction.DESC, "createdAt")
        );
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
