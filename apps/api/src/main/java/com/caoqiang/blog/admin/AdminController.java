package com.caoqiang.blog.admin;

import com.caoqiang.blog.ai.AiChatSessionRepository;
import com.caoqiang.blog.ai.KnowledgeDocRepository;
import com.caoqiang.blog.audit.AuditLogResponse;
import com.caoqiang.blog.audit.AuditLogService;
import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.content.ContentRepository;
import com.caoqiang.blog.content.MediaAssetRepository;
import com.caoqiang.blog.friend.FriendRepository;
import com.caoqiang.blog.interaction.CommentRepository;
import com.caoqiang.blog.interaction.LikeRepository;
import com.caoqiang.blog.interaction.ViewRecordRepository;
import com.caoqiang.blog.user.UserRepository;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 管理端仪表盘控制器
 * <p>
 * 提供管理后台的仪表盘数据和系统信息查询功能。
 * <p>
 * 主要职责：
 * <ul>
 *   <li>提供系统统计数据（内容、媒体、用户等数量）</li>
 *   <li>提供审计日志查询</li>
 *   <li>提供可用模块列表</li>
 * </ul>
 * <p>
 * 所有端点均需管理员身份认证。
 * 基础路径: {@code /api/v1/admin}
 */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminController {

    /** 内容数据访问层 */
    private final ContentRepository contentRepository;
    /** 媒体资源数据访问层 */
    private final MediaAssetRepository mediaAssetRepository;
    /** 友链数据访问层 */
    private final FriendRepository friendRepository;
    /** 用户数据访问层 */
    private final UserRepository userRepository;
    /** 评论数据访问层 */
    private final CommentRepository commentRepository;
    /** 点赞数据访问层 */
    private final LikeRepository likeRepository;
    /** 浏览记录数据访问层 */
    private final ViewRecordRepository viewRecordRepository;
    /** AI 聊天会话数据访问层 */
    private final AiChatSessionRepository aiChatSessionRepository;
    /** 知识库文档数据访问层 */
    private final KnowledgeDocRepository knowledgeDocRepository;
    /** 审计日志服务 */
    private final AuditLogService auditLogService;

    public AdminController(
            ContentRepository contentRepository,
            MediaAssetRepository mediaAssetRepository,
            FriendRepository friendRepository,
            UserRepository userRepository,
            CommentRepository commentRepository,
            LikeRepository likeRepository,
            ViewRecordRepository viewRecordRepository,
            AiChatSessionRepository aiChatSessionRepository,
            KnowledgeDocRepository knowledgeDocRepository,
            AuditLogService auditLogService
    ) {
        this.contentRepository = contentRepository;
        this.mediaAssetRepository = mediaAssetRepository;
        this.friendRepository = friendRepository;
        this.userRepository = userRepository;
        this.commentRepository = commentRepository;
        this.likeRepository = likeRepository;
        this.viewRecordRepository = viewRecordRepository;
        this.aiChatSessionRepository = aiChatSessionRepository;
        this.knowledgeDocRepository = knowledgeDocRepository;
        this.auditLogService = auditLogService;
    }

    /**
     * 获取仪表盘统计数据
     * <p>
     * 返回系统各模块的数据统计，用于管理后台首页展示。
     *
     * @return 仪表盘统计数据
     */
    @GetMapping("/dashboard")
    public ApiResponse<DashboardStats> dashboard() {
        return ApiResponse.ok(new DashboardStats(
                contentRepository.count(),
                mediaAssetRepository.count(),
                friendRepository.count(),
                userRepository.count(),
                commentRepository.count(),
                likeRepository.count(),
                viewRecordRepository.count(),
                aiChatSessionRepository.count(),
                knowledgeDocRepository.count()
        ));
    }

    /**
     * 获取审计日志列表（分页、筛选）
     *
     * @param page         页码，从 0 开始
     * @param size         每页大小，默认 50
     * @param action       操作类型筛选条件
     * @param resourceType 资源类型筛选条件
     * @param actorUserId  操作者用户 ID 筛选条件
     * @return 审计日志分页响应
     */
    @GetMapping("/logs")
    public ApiResponse<PageResponse<AuditLogResponse>> logs(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size,
            @RequestParam(required = false) String action,
            @RequestParam(required = false) String resourceType,
            @RequestParam(required = false) UUID actorUserId
    ) {
        return ApiResponse.ok(auditLogService.list(page, size, action, resourceType, actorUserId));
    }

    /**
     * 获取可用模块列表
     * <p>
     * 返回管理后台所有可用的模块标识，用于前端动态渲染导航菜单。
     *
     * @return 模块标识列表
     */
    @GetMapping("/modules")
    public ApiResponse<List<String>> modules() {
        return ApiResponse.ok(List.of(
                "tags",
                "contents",
                "media",
                "comments",
                "views",
                "likes",
                "friends",
                "users",
                "ai-chats",
                "knowledge",
                "logs"
        ));
    }
}
