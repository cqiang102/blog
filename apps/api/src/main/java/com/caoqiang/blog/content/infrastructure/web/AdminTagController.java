package com.caoqiang.blog.content.infrastructure.web;

import com.caoqiang.blog.content.application.dto.TagRequest;
import com.caoqiang.blog.content.application.dto.TagResponse;
import com.caoqiang.blog.content.application.service.TagAdminService;
import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.shared.response.OperationResult;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 管理端标签 CRUD 控制器
 * <p>
 * 提供管理员对内容标签的完整 CRUD 操作，包括：
 * <ul>
 *   <li>标签列表查询</li>
 *   <li>创建新标签</li>
 *   <li>更新标签信息</li>
 *   <li>删除标签</li>
 * </ul>
 * <p>
 * 所有端点均需管理员身份认证。
 * 基础路径: {@code /api/v1/admin/tags}
 */
@RestController
@RequestMapping("/api/v1/admin/tags")
public class AdminTagController {

    /** 标签管理服务 */
    private final TagAdminService tagAdminService;

    public AdminTagController(TagAdminService tagAdminService) {
        this.tagAdminService = tagAdminService;
    }

    /**
     * 获取标签列表
     *
     * @return 标签响应列表
     */
    @GetMapping
    public ApiResponse<List<TagResponse>> list() {
        return ApiResponse.ok(tagAdminService.list());
    }

    /**
     * 创建新标签
     *
     * @param request 标签请求体
     * @return 创建后的标签响应 DTO
     */
    @PostMapping
    public ApiResponse<TagResponse> create(@Valid @RequestBody TagRequest request) {
        return ApiResponse.ok(tagAdminService.create(request));
    }

    /**
     * 更新标签信息
     *
     * @param id      标签 ID
     * @param request 标签请求体
     * @return 更新后的标签响应 DTO
     */
    @PutMapping("/{id}")
    public ApiResponse<TagResponse> update(@PathVariable UUID id, @Valid @RequestBody TagRequest request) {
        return ApiResponse.ok(tagAdminService.update(id, request));
    }

    /**
     * 删除标签
     *
     * @param id 标签 ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    public ApiResponse<OperationResult> delete(@PathVariable UUID id) {
        tagAdminService.delete(id);
        return ApiResponse.ok(OperationResult.deleted(id));
    }
}
