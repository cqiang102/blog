package com.caoqiang.blog.interaction.infrastructure.web;

import com.caoqiang.blog.config.ClientIpResolver;
import com.caoqiang.blog.interaction.application.dto.CommentRequest;
import com.caoqiang.blog.interaction.application.dto.CommentResponse;
import com.caoqiang.blog.interaction.application.dto.LikeStateResponse;
import com.caoqiang.blog.interaction.application.dto.ViewStateResponse;
import com.caoqiang.blog.interaction.application.service.InteractionCommandService;
import com.caoqiang.blog.interaction.application.service.InteractionQueryService;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.shared.response.OperationResult;
import com.caoqiang.blog.shared.response.PageResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 互动 REST 控制器
 * <p>
 * 负责处理博客内容的互动功能，包括评论、点赞和浏览记录。
 * 位于 API 层，接收前端请求并委托给 {@link InteractionQueryService} 和 {@link InteractionCommandService} 处理业务逻辑。
 * </p>
 * <p>
 * 主要功能：
 * <ul>
 *   <li>评论的增删查</li>
 *   <li>内容的点赞/取消点赞</li>
 *   <li>浏览记录的创建</li>
 * </ul>
 * </p>
 */
@RestController
@RequestMapping("/api/v1")
public class InteractionController {

    /** 互动查询服务，处理评论列表、用户活动等只读操作 */
    private final InteractionQueryService interactionQueryService;
    /** 互动命令服务，处理评论、点赞、浏览记录等写操作 */
    private final InteractionCommandService interactionCommandService;

    private final ClientIpResolver clientIpResolver;

    /**
     * 构造函数，注入互动服务
     *
     * @param interactionQueryService   互动查询服务
     * @param interactionCommandService 互动命令服务
     */
    public InteractionController(
            InteractionQueryService interactionQueryService,
            InteractionCommandService interactionCommandService,
            ClientIpResolver clientIpResolver) {
        this.interactionQueryService = interactionQueryService;
        this.interactionCommandService = interactionCommandService;
        this.clientIpResolver = clientIpResolver;
    }

    /**
     * 获取指定内容的评论列表（分页）
     * <p>
     * 支持匿名访问，如果用户已登录则返回该用户对评论的点赞状态。
     * </p>
     *
     * @param currentUser 当前登录用户（可为 null，表示匿名用户）
     * @param contentId   内容 ID
     * @param page        页码，从 0 开始
     * @param size        每页大小，默认 20
     * @return 包含评论列表的分页响应
     */
    @GetMapping("/contents/{contentId}/comments")
    public ApiResponse<PageResponse<CommentResponse>> comments(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID contentId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        UUID userId = currentUser != null ? currentUser.id() : null;
        return ApiResponse.ok(interactionQueryService.comments(contentId, page, size, userId));
    }

    /**
     * 发表评论
     * <p>
     * 需要用户登录。评论会进入审核流程（可能由 AI 进行内容审查）。
     * </p>
     *
     * @param currentUser 当前登录用户
     * @param contentId   内容 ID
     * @param request     评论请求体，包含评论内容和可选的父评论 ID
     * @return 创建的评论信息
     */
    @PostMapping("/contents/{contentId}/comments")
    public ApiResponse<CommentResponse> comment(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID contentId,
            @Valid @RequestBody CommentRequest request) {
        return ApiResponse.ok(interactionCommandService.comment(currentUser, contentId, request));
    }

    /**
     * 删除评论
     * <p>
     * 只能删除自己的评论。删除后返回确认信息。
     * </p>
     *
     * @param currentUser 当前登录用户
     * @param commentId   要删除的评论 ID
     * @return 操作结果
     */
    @DeleteMapping("/comments/{commentId}")
    public ApiResponse<OperationResult> deleteComment(
            @AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID commentId) {
        interactionCommandService.deleteComment(currentUser, commentId);
        return ApiResponse.ok(OperationResult.deleted(commentId));
    }

    /**
     * 点赞内容
     * <p>
     * 需要用户登录。如果已经点赞则不会重复点赞。
     * </p>
     *
     * @param currentUser 当前登录用户
     * @param contentId   内容 ID
     * @return 点赞状态响应，包含是否已点赞和总点赞数
     */
    @PostMapping("/contents/{contentId}/likes")
    public ApiResponse<LikeStateResponse> like(
            @AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID contentId) {
        return ApiResponse.ok(interactionCommandService.like(currentUser, contentId));
    }

    /**
     * 取消点赞内容
     * <p>
     * 需要用户登录。如果未点赞则不会执行操作。
     * </p>
     *
     * @param currentUser 当前登录用户
     * @param contentId   内容 ID
     * @return 点赞状态响应，包含是否已点赞和总点赞数
     */
    @DeleteMapping("/contents/{contentId}/likes")
    public ApiResponse<LikeStateResponse> unlike(
            @AuthenticationPrincipal AuthenticatedUser currentUser, @PathVariable UUID contentId) {
        return ApiResponse.ok(interactionCommandService.unlike(currentUser, contentId));
    }

    /**
     * 记录内容浏览
     * <p>
     * 支持匿名浏览记录，通过 IP 和 User-Agent 进行 SHA-256 匿名去重，
     * 防止同一用户短时间内重复计数。
     * </p>
     *
     * @param currentUser 当前登录用户（可为 null）
     * @param contentId   内容 ID
     * @param request     HTTP 请求，用于获取客户端 IP 和 User-Agent
     * @return 浏览状态响应，包含是否为新浏览和总浏览数
     */
    @PostMapping("/contents/{contentId}/views")
    public ApiResponse<ViewStateResponse> recordView(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID contentId,
            HttpServletRequest request) {
        String clientIp = clientIpResolver.resolve(request);
        String userAgent = request.getHeader("User-Agent");
        return ApiResponse.ok(interactionCommandService.recordView(currentUser, contentId, clientIp, userAgent));
    }
}
