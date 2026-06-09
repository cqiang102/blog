package com.caoqiang.blog.interaction.infrastructure.web;

import com.caoqiang.blog.interaction.application.dto.AdminCommentResponse;
import com.caoqiang.blog.interaction.application.dto.AdminCommentStatusRequest;
import com.caoqiang.blog.interaction.application.dto.AdminLikeResponse;
import com.caoqiang.blog.interaction.application.dto.AdminViewRecordResponse;
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
import com.caoqiang.blog.interaction.application.service.CommentAdminService;
import com.caoqiang.blog.interaction.application.service.InteractionAdminService;

import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.shared.response.OperationResult;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.interaction.application.dto.AdminCommentResponse;
import com.caoqiang.blog.interaction.application.dto.AdminCommentStatusRequest;
import com.caoqiang.blog.interaction.application.service.CommentAdminService;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 管理端评论控制器
 * <p>
 * 提供管理员对评论的管理操作，包括：
 * <ul>
 *   <li>评论列表查询（支持按状态、内容、用户筛选）</li>
 *   <li>设置评论状态（审核通过/拒绝）</li>
 *   <li>删除评论</li>
 * </ul>
 * <p>
 * 所有端点均需管理员身份认证。
 * 基础路径: {@code /api/v1/admin/comments}
 */
@RestController
@RequestMapping("/api/v1/admin/comments")
public class AdminCommentController {

    /** 评论管理服务 */
    private final CommentAdminService commentAdminService;

    public AdminCommentController(CommentAdminService commentAdminService) {
        this.commentAdminService = commentAdminService;
    }

    /**
     * 获取评论列表（分页、筛选）
     *
     * @param page      页码，从 0 开始
     * @param size      每页大小，默认 20
     * @param status    评论状态筛选条件
     * @param contentId 内容 ID 筛选条件
     * @param userId    用户 ID 筛选条件
     * @return 评论列表分页响应
     */
    @GetMapping
    public ApiResponse<PageResponse<AdminCommentResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) CommentStatus status,
            @RequestParam(required = false) UUID contentId,
            @RequestParam(required = false) UUID userId
    ) {
        return ApiResponse.ok(commentAdminService.list(page, size, status, contentId, userId));
    }

    /**
     * 设置评论状态
     * <p>
     * 用于审核评论，支持设置为通过或拒绝状态。
     *
     * @param id      评论 ID
     * @param request 状态请求体
     * @return 更新后的评论响应 DTO
     */
    @PutMapping("/{id}/status")
    public ApiResponse<AdminCommentResponse> setStatus(
            @PathVariable UUID id,
            @Valid @RequestBody AdminCommentStatusRequest request
    ) {
        return ApiResponse.ok(commentAdminService.setStatus(id, request.status()));
    }

    /**
     * 删除评论
     *
     * @param id 评论 ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    public ApiResponse<OperationResult> delete(@PathVariable UUID id) {
        commentAdminService.delete(id);
        return ApiResponse.ok(OperationResult.deleted(id));
    }
}
