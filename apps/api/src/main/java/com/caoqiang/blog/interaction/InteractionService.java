package com.caoqiang.blog.interaction;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.shared.util.PageUtils;
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
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 互动核心服务
 * <p>
 * 负责处理博客内容的互动业务逻辑，包括评论、点赞和浏览记录。
 * 位于服务层，被 {@link InteractionController} 调用，操作数据库完成业务。
 * </p>
 * <p>
 * 关键特性：
 * <ul>
 *   <li>评论 CRUD，支持审核状态管理</li>
 *   <li>点赞/取消点赞，防重复点赞</li>
 *   <li>浏览记录，使用 SHA-256 对 IP 和 User-Agent 进行匿名去重</li>
 *   <li>用户活动查询（我的评论、点赞、浏览记录）</li>
 * </ul>
 * </p>
 */
@Service
public class InteractionService {

    /** 最大分页大小限制 */
    private static final int MAX_PAGE_SIZE = 50;
    /** URL 安全的 Base64 编码器（无填充） */
    private static final Base64.Encoder BASE64_ENCODER = Base64.getUrlEncoder().withoutPadding();

    /** 内容仓储 */
    private final ContentRepository contentRepository;
    /** 用户仓储 */
    private final UserRepository userRepository;
    /** 评论仓储 */
    private final CommentRepository commentRepository;
    /** 点赞仓储 */
    private final LikeRepository likeRepository;
    /** 浏览记录仓储 */
    private final ViewRecordRepository viewRecordRepository;
    /** 评论审核服务（AI 异步审查） */
    private final CommentAuditService commentAuditService;

    /**
     * 构造函数，注入所有依赖的仓储和服务
     *
     * @param contentRepository    内容仓储
     * @param userRepository       用户仓储
     * @param commentRepository    评论仓储
     * @param likeRepository       点赞仓储
     * @param viewRecordRepository 浏览记录仓储
     * @param commentAuditService  评论审核服务
     */
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

    /**
     * 获取指定内容的评论列表（分页）
     * <p>
     * 只返回可见评论和当前用户自己的被屏蔽评论（如果已登录）。
     * 使用数据库层面过滤避免分页总数不准确的问题。
     * </p>
     *
     * @param contentId     内容 ID
     * @param page          页码，从 0 开始
     * @param size          每页大小
     * @param currentUserId 当前用户 ID（可为 null）
     * @return 评论响应的分页结果
     */
    @Transactional(readOnly = true)
    public PageResponse<CommentResponse> comments(UUID contentId, int page, int size, UUID currentUserId) {
        Page<Comment> result;
        if (currentUserId == null) {
            // 匿名用户：只查询可见评论
            result = commentRepository.findByContentIdAndStatusOrderByCreatedAtDesc(
                    contentId,
                    CommentStatus.VISIBLE,
                    pageRequest(page, size)
            );
        } else {
            // 登录用户：查询可见评论 + 自己的被屏蔽评论
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

    /**
     * 发表评论
     * <p>
     * 保存评论后触发 AI 异步审核。审核通过前评论状态为 PENDING。
     * </p>
     *
     * @param currentUser 当前登录用户
     * @param contentId   内容 ID
     * @param request     评论请求体
     * @return 创建的评论响应
     */
    @Transactional
    public CommentResponse comment(AuthenticatedUser currentUser, UUID contentId, CommentRequest request) {
        Content content = publishedContent(contentId);
        User user = activeUser(currentUser.id());
        // 保存评论（初始状态为 PENDING）
        Comment comment = commentRepository.save(new Comment(content, user, request.body().trim()));
        // 增加内容的评论计数
        contentRepository.incrementCommentCount(contentId, 1);

        // 触发 AI 异步审核
        commentAuditService.audit(comment.getId());

        return CommentResponse.from(comment);
    }

    /**
     * 删除评论。
     * <p>
     * 只能删除自己的评论（管理员除外）。已删除状态的评论不重复处理。
     * 对于可见评论，删除后减少内容的评论计数；对于不可见评论（BLOCKED/PENDING），
     * 仅标记为删除，不减少计数（因为不可见评论未计入 commentCount）。
     * </p>
     *
     * @param currentUser 当前登录用户
     * @param commentId   要删除的评论 ID
     */
    @Transactional
    public void deleteComment(AuthenticatedUser currentUser, UUID commentId) {
        Comment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "评论不存在"));
        // 权限检查：只能删除自己的评论，管理员除外
        if (!comment.getUser().getId().equals(currentUser.id()) && currentUser.role() != Role.ADMIN) {
            throw new BusinessException(HttpStatus.FORBIDDEN, "只能删除自己的评论");
        }
        // 已删除的评论不重复处理
        if (comment.getStatus() == CommentStatus.DELETED) {
            return;
        }
        // 只有可见评论才需要减少计数（不可见评论未计入 commentCount）
        if (comment.isVisible()) {
            contentRepository.incrementCommentCount(comment.getContent().getId(), -1);
        }
        comment.markDeleted();
    }

    /**
     * 点赞内容
     * <p>
     * 如果用户已经点赞，则直接返回当前状态，不会重复点赞。
     * </p>
     *
     * @param currentUser 当前登录用户
     * @param contentId   内容 ID
     * @return 点赞状态响应
     */
    @Transactional
    public LikeStateResponse like(AuthenticatedUser currentUser, UUID contentId) {
        Content content = publishedContent(contentId);
        User user = activeUser(currentUser.id());
        // 检查是否已经点赞，防止重复
        if (likeRepository.existsByContentIdAndUserId(contentId, currentUser.id())) {
            return new LikeStateResponse(contentId, true, content.getLikeCount());
        }

        // 创建点赞记录并增加计数
        likeRepository.save(new Like(content, user));
        contentRepository.incrementLikeCount(contentId, 1);
        return new LikeStateResponse(contentId, true, content.getLikeCount() + 1);
    }

    /**
     * 取消点赞内容
     * <p>
     * 如果用户未点赞，则直接返回当前状态。
     * </p>
     *
     * @param currentUser 当前登录用户
     * @param contentId   内容 ID
     * @return 点赞状态响应
     */
    @Transactional
    public LikeStateResponse unlike(AuthenticatedUser currentUser, UUID contentId) {
        Content content = publishedContent(contentId);
        return likeRepository.findByContentIdAndUserId(contentId, currentUser.id())
                .map(like -> {
                    // 找到点赞记录，删除并减少计数
                    likeRepository.delete(like);
                    contentRepository.incrementLikeCount(contentId, -1);
                    return new LikeStateResponse(contentId, false, Math.max(0, content.getLikeCount() - 1));
                })
                .orElseGet(() -> new LikeStateResponse(contentId, false, content.getLikeCount()));
    }

    /**
     * 记录内容浏览
     * <p>
     * 使用 SHA-256 对 IP 和 User-Agent 进行匿名去重，防止同一用户短时间内重复计数。
     * 已登录用户通过用户 ID 去重，匿名用户通过匿名 ID 去重。
     * </p>
     *
     * @param currentUser 当前登录用户（可为 null）
     * @param contentId   内容 ID
     * @param clientIp    客户端 IP 地址
     * @param userAgent   User-Agent 字符串
     * @return 浏览状态响应
     */
    @Transactional
    public ViewStateResponse recordView(AuthenticatedUser currentUser, UUID contentId, String clientIp, String userAgent) {
        Content content = publishedContent(contentId);
        User user = currentUser == null ? null : activeUser(currentUser.id());

        // 生成匿名 ID（IP + User-Agent 的 SHA-256 哈希）
        String anonymousId = generateAnonymousId(clientIp, userAgent);
        // 对 IP 进行哈希，用于存储（保护用户隐私）
        String ipHash = hashIp(clientIp);

        // 去重检查：已登录用户用用户 ID，匿名用户用匿名 ID
        if (user != null) {
            if (viewRecordRepository.existsByContentIdAndUserId(contentId, user.getId())) {
                return new ViewStateResponse(contentId, true, content.getViewCount());
            }
        } else {
            if (viewRecordRepository.existsByContentIdAndAnonymousId(contentId, anonymousId)) {
                return new ViewStateResponse(contentId, true, content.getViewCount());
            }
        }

        // 保存浏览记录并增加计数
        viewRecordRepository.save(new ViewRecord(content, user, anonymousId, ipHash, userAgent));
        contentRepository.incrementViewCount(contentId, 1);
        return new ViewStateResponse(contentId, true, content.getViewCount() + 1);
    }

    /**
     * 获取当前用户的评论列表（分页）
     *
     * @param currentUser 当前登录用户
     * @param page        页码
     * @param size        每页大小
     * @return 用户活动响应的分页结果
     */
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

    /**
     * 获取当前用户的点赞列表（分页）
     *
     * @param currentUser 当前登录用户
     * @param page        页码
     * @param size        每页大小
     * @return 用户活动响应的分页结果
     */
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

    /**
     * 获取当前用户的浏览记录列表（分页）
     *
     * @param currentUser 当前登录用户
     * @param page        页码
     * @param size        每页大小
     * @return 用户活动响应的分页结果
     */
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

    /**
     * 删除当前用户的点赞记录
     *
     * @param currentUser 当前登录用户
     * @param contentId   内容 ID
     */
    @Transactional
    public void deleteMyLike(AuthenticatedUser currentUser, UUID contentId) {
        unlike(currentUser, contentId);
    }

    /**
     * 删除当前用户的浏览记录
     *
     * @param currentUser  当前登录用户
     * @param viewRecordId 浏览记录 ID
     */
    @Transactional
    public void deleteMyView(AuthenticatedUser currentUser, UUID viewRecordId) {
        ViewRecord viewRecord = viewRecordRepository.findByIdAndUserId(viewRecordId, currentUser.id())
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "浏览记录不存在"));
        viewRecordRepository.delete(viewRecord);
        contentRepository.incrementViewCount(viewRecord.getContent().getId(), -1);
    }

    /**
     * 获取已发布的内容
     *
     * @param contentId 内容 ID
     * @return 内容实体
     * @throws BusinessException 如果内容不存在或未发布
     */
    private Content publishedContent(UUID contentId) {
        return contentRepository.findByIdAndStatus(contentId, ContentStatus.PUBLISHED)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
    }

    /**
     * 获取活跃用户
     *
     * @param userId 用户 ID
     * @return 用户实体
     * @throws BusinessException 如果用户不存在或未激活
     */
    private User activeUser(UUID userId) {
        return userRepository.findById(userId)
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }

    /**
     * 创建分页请求对象
     * <p>
     * 对参数进行边界检查：page >= 0, 1 <= size <= MAX_PAGE_SIZE
     * </p>
     *
     * @param page 页码
     * @param size 每页大小
     * @return 分页请求对象
     */
    private PageRequest pageRequest(int page, int size) {
        return PageUtils.of(page, size, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "createdAt"));
    }

    /**
     * 生成匿名用户 ID
     * <p>
     * 将 IP 和 User-Agent 拼接后进行 SHA-256 哈希，用于匿名去重。
     * </p>
     *
     * @param clientIp  客户端 IP
     * @param userAgent User-Agent 字符串
     * @return 匿名 ID（Base64 编码的 SHA-256 哈希）
     */
    private String generateAnonymousId(String clientIp, String userAgent) {
        String raw = (clientIp != null ? clientIp : "unknown") + "|" + (userAgent != null ? userAgent : "unknown");
        return hashString(raw);
    }

    /**
     * 对 IP 地址进行哈希处理
     *
     * @param clientIp 客户端 IP
     * @return IP 哈希值（Base64 编码的 SHA-256 哈希）
     */
    private String hashIp(String clientIp) {
        return hashString(clientIp != null ? clientIp : "unknown");
    }

    /**
     * 使用 SHA-256 对字符串进行哈希
     *
     * @param input 输入字符串
     * @return Base64 编码的哈希值
     * @throws IllegalStateException 如果哈希算法不可用
     */
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
