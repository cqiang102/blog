package com.caoqiang.blog.admin;

import com.caoqiang.blog.ai.AdminAiChatDetailResponse;
import com.caoqiang.blog.ai.AdminAiChatSessionResponse;
import com.caoqiang.blog.ai.AiChatAdminService;
import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.OperationResult;
import com.caoqiang.blog.common.PageResponse;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 管理端 AI 聊天控制器
 * <p>
 * 提供管理员对 AI 聊天会话的管理操作，包括：
 * <ul>
 *   <li>聊天会话列表查询（支持按用户、关键词筛选）</li>
 *   <li>聊天会话详情查看（包含完整对话记录）</li>
 *   <li>删除聊天会话</li>
 * </ul>
 * <p>
 * 所有端点均需管理员身份认证。
 * 基础路径: {@code /api/v1/admin/ai/chats}
 */
@RestController
@RequestMapping("/api/v1/admin/ai/chats")
public class AdminAiChatController {

    /** AI 聊天管理服务 */
    private final AiChatAdminService aiChatAdminService;

    public AdminAiChatController(AiChatAdminService aiChatAdminService) {
        this.aiChatAdminService = aiChatAdminService;
    }

    /**
     * 获取 AI 聊天会话列表（分页、筛选）
     *
     * @param page   页码，从 0 开始
     * @param size   每页大小，默认 20
     * @param userId 用户 ID 筛选条件
     * @param query  搜索关键词
     * @return 聊天会话列表分页响应
     */
    @GetMapping
    public ApiResponse<PageResponse<AdminAiChatSessionResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) UUID userId,
            @RequestParam(required = false) String query
    ) {
        return ApiResponse.ok(aiChatAdminService.sessions(page, size, userId, query));
    }

    /**
     * 获取 AI 聊天会话详情
     * <p>
     * 返回会话的完整对话记录。
     *
     * @param id 会话 ID
     * @return 聊天会话详情响应 DTO
     */
    @GetMapping("/{id}")
    public ApiResponse<AdminAiChatDetailResponse> detail(@PathVariable UUID id) {
        return ApiResponse.ok(aiChatAdminService.detail(id));
    }

    /**
     * 删除 AI 聊天会话
     *
     * @param id 会话 ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    public ApiResponse<OperationResult> delete(@PathVariable UUID id) {
        aiChatAdminService.delete(id);
        return ApiResponse.ok(OperationResult.deleted(id));
    }
}
