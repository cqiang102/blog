package com.caoqiang.blog.interaction.admin;

import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.shared.response.OperationResult;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.interaction.AdminLikeResponse;
import com.caoqiang.blog.interaction.AdminViewRecordResponse;
import com.caoqiang.blog.interaction.InteractionAdminService;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 管理端互动记录控制器
 * <p>
 * 提供管理员对用户互动记录（点赞、浏览）的管理操作，包括：
 * <ul>
 *   <li>点赞记录列表查询（支持按内容、用户筛选）</li>
 *   <li>删除点赞记录</li>
 *   <li>浏览记录列表查询（支持按内容、用户筛选）</li>
 *   <li>删除浏览记录</li>
 * </ul>
 * <p>
 * 所有端点均需管理员身份认证。
 * 基础路径: {@code /api/v1/admin}
 */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminInteractionRecordController {

    /** 互动记录管理服务 */
    private final InteractionAdminService interactionAdminService;

    public AdminInteractionRecordController(InteractionAdminService interactionAdminService) {
        this.interactionAdminService = interactionAdminService;
    }

    /**
     * 获取点赞记录列表（分页、筛选）
     *
     * @param page      页码，从 0 开始
     * @param size      每页大小，默认 20
     * @param contentId 内容 ID 筛选条件
     * @param userId    用户 ID 筛选条件
     * @return 点赞记录列表分页响应
     */
    @GetMapping("/likes")
    public ApiResponse<PageResponse<AdminLikeResponse>> likes(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) UUID contentId,
            @RequestParam(required = false) UUID userId
    ) {
        return ApiResponse.ok(interactionAdminService.likes(page, size, contentId, userId));
    }

    /**
     * 删除点赞记录
     *
     * @param id 点赞记录 ID
     * @return 操作结果
     */
    @DeleteMapping("/likes/{id}")
    public ApiResponse<OperationResult> deleteLike(@PathVariable UUID id) {
        interactionAdminService.deleteLike(id);
        return ApiResponse.ok(OperationResult.deleted(id));
    }

    /**
     * 获取浏览记录列表（分页、筛选）
     *
     * @param page      页码，从 0 开始
     * @param size      每页大小，默认 20
     * @param contentId 内容 ID 筛选条件
     * @param userId    用户 ID 筛选条件
     * @return 浏览记录列表分页响应
     */
    @GetMapping("/views")
    public ApiResponse<PageResponse<AdminViewRecordResponse>> views(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) UUID contentId,
            @RequestParam(required = false) UUID userId
    ) {
        return ApiResponse.ok(interactionAdminService.views(page, size, contentId, userId));
    }

    /**
     * 删除浏览记录
     *
     * @param id 浏览记录 ID
     * @return 操作结果
     */
    @DeleteMapping("/views/{id}")
    public ApiResponse<OperationResult> deleteView(@PathVariable UUID id) {
        interactionAdminService.deleteView(id);
        return ApiResponse.ok(OperationResult.deleted(id));
    }
}
