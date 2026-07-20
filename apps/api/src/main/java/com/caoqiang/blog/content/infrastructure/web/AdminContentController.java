package com.caoqiang.blog.content.infrastructure.web;

import com.caoqiang.blog.content.application.dto.AdminContentOptionResponse;
import com.caoqiang.blog.content.application.dto.AdminContentRequest;
import com.caoqiang.blog.content.application.dto.AdminContentResponse;
import com.caoqiang.blog.content.application.service.ContentAdminService;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.shared.response.OperationResult;
import com.caoqiang.blog.shared.response.PageResponse;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 管理端内容 CRUD 控制器
 * <p>
 * 提供管理员对博客内容的完整 CRUD 操作，包括：
 * <ul>
 *   <li>内容列表查询（分页）</li>
 *   <li>内容详情查看</li>
 *   <li>创建新内容</li>
 *   <li>更新内容</li>
 *   <li>归档内容（软删除）</li>
 * </ul>
 * <p>
 * 所有端点均需管理员身份认证。
 * 基础路径: {@code /api/v1/admin/contents}
 */
@RestController
@RequestMapping("/api/v1/admin/contents")
public class AdminContentController {

    /** 内容管理服务 */
    private final ContentAdminService contentAdminService;

    public AdminContentController(ContentAdminService contentAdminService) {
        this.contentAdminService = contentAdminService;
    }

    /**
     * 获取内容列表（分页），支持搜索和筛选
     *
     * @param page           页码，从 0 开始
     * @param size           每页大小，默认 20
     * @param includeDeleted 是否包含已逻辑删除的内容，默认 false
     * @param query          搜索关键词（模糊匹配标题、摘要）
     * @param status         内容状态过滤
     * @param type           内容类型过滤
     * @return 内容列表分页响应
     */
    @GetMapping
    public ApiResponse<PageResponse<AdminContentResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "false") boolean includeDeleted,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) ContentStatus status,
            @RequestParam(required = false) ContentType type) {
        return ApiResponse.ok(contentAdminService.list(page, size, includeDeleted, query, status, type));
    }

    /** Returns lightweight content choices for remote-search management controls. */
    @GetMapping("/options")
    public ApiResponse<PageResponse<AdminContentOptionResponse>> listOptions(
            @RequestParam(defaultValue = "") String query,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(contentAdminService.options(query, page, size));
    }

    /**
     * 获取内容详情
     *
     * @param id 内容 ID
     * @return 内容详情响应 DTO
     */
    @GetMapping("/{id}")
    public ApiResponse<AdminContentResponse> detail(@PathVariable UUID id) {
        return ApiResponse.ok(contentAdminService.detail(id));
    }

    /**
     * 创建新内容
     *
     * @param request 内容请求体
     * @return 创建后的内容详情响应 DTO
     */
    @PostMapping
    public ApiResponse<AdminContentResponse> create(@Valid @RequestBody AdminContentRequest request) {
        return ApiResponse.ok(contentAdminService.create(request));
    }

    /**
     * 更新内容
     *
     * @param id      内容 ID
     * @param request 内容请求体
     * @return 更新后的内容详情响应 DTO
     */
    @PutMapping("/{id}")
    public ApiResponse<AdminContentResponse> update(
            @PathVariable UUID id, @Valid @RequestBody AdminContentRequest request) {
        return ApiResponse.ok(contentAdminService.update(id, request));
    }

    /**
     * 逻辑删除内容
     * <p>
     * 设置 deletedAt 字段，实现逻辑删除。与归档操作分离。
     *
     * @param id 内容 ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    public ApiResponse<OperationResult> softDelete(@PathVariable UUID id) {
        contentAdminService.softDelete(id);
        return ApiResponse.ok(OperationResult.deleted(id));
    }

    /**
     * 恢复已逻辑删除的内容
     *
     * @param id 内容 ID
     * @return 操作结果
     */
    @PutMapping("/{id}/restore")
    public ApiResponse<OperationResult> restore(@PathVariable UUID id) {
        contentAdminService.restore(id);
        return ApiResponse.ok(OperationResult.restored(id));
    }
}
