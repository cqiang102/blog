package com.caoqiang.blog.admin;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.OperationResult;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.content.AdminContentRequest;
import com.caoqiang.blog.content.AdminContentResponse;
import com.caoqiang.blog.content.ContentAdminService;
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
     * 获取内容列表（分页）
     *
     * @param page 页码，从 0 开始
     * @param size 每页大小，默认 20
     * @return 内容列表分页响应
     */
    @GetMapping
    public ApiResponse<PageResponse<AdminContentResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return ApiResponse.ok(contentAdminService.list(page, size));
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
            @PathVariable UUID id,
            @Valid @RequestBody AdminContentRequest request
    ) {
        return ApiResponse.ok(contentAdminService.update(id, request));
    }

    /**
     * 归档内容（软删除）
     * <p>
     * 将内容状态设置为已归档，不会物理删除数据。
     *
     * @param id 内容 ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    public ApiResponse<OperationResult> archive(@PathVariable UUID id) {
        contentAdminService.archive(id);
        return ApiResponse.ok(OperationResult.archived(id));
    }
}
