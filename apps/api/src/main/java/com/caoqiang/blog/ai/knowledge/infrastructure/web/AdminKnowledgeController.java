package com.caoqiang.blog.ai.knowledge.infrastructure.web;

import com.caoqiang.blog.ai.knowledge.application.dto.KnowledgeDocRequest;
import com.caoqiang.blog.ai.knowledge.application.dto.KnowledgeDocResponse;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeAdminService;
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
 * 管理端知识库控制器
 * <p>
 * 提供管理员对知识库文档的完整 CRUD 操作，包括：
 * <ul>
 *   <li>知识库文档列表查询（支持按关键词、启用状态筛选）</li>
 *   <li>知识库文档详情查看</li>
 *   <li>创建新知识库文档</li>
 *   <li>更新知识库文档</li>
 *   <li>删除知识库文档</li>
 * </ul>
 * <p>
 * 知识库文档用于 AI 聊天功能的上下文参考。
 * 所有端点均需管理员身份认证。
 * 基础路径: {@code /api/v1/admin/knowledge/docs}
 */
@RestController
@RequestMapping("/api/v1/admin/knowledge/docs")
public class AdminKnowledgeController {

    /** 知识库管理服务 */
    private final KnowledgeAdminService knowledgeAdminService;

    public AdminKnowledgeController(KnowledgeAdminService knowledgeAdminService) {
        this.knowledgeAdminService = knowledgeAdminService;
    }

    /**
     * 获取知识库文档列表（分页、筛选）
     *
     * @param page    页码，从 0 开始
     * @param size    每页大小，默认 20
     * @param query   搜索关键词
     * @param enabled 启用状态筛选条件
     * @return 知识库文档列表分页响应
     */
    @GetMapping
    public ApiResponse<PageResponse<KnowledgeDocResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) Boolean enabled
    ) {
        return ApiResponse.ok(knowledgeAdminService.list(page, size, query, enabled));
    }

    /**
     * 获取知识库文档详情
     *
     * @param id 文档 ID
     * @return 知识库文档详情响应 DTO
     */
    @GetMapping("/{id}")
    public ApiResponse<KnowledgeDocResponse> detail(@PathVariable UUID id) {
        return ApiResponse.ok(knowledgeAdminService.detail(id));
    }

    /**
     * 创建新知识库文档
     *
     * @param request 知识库文档请求体
     * @return 创建后的知识库文档响应 DTO
     */
    @PostMapping
    public ApiResponse<KnowledgeDocResponse> create(@Valid @RequestBody KnowledgeDocRequest request) {
        return ApiResponse.ok(knowledgeAdminService.create(request));
    }

    /**
     * 更新知识库文档
     *
     * @param id      文档 ID
     * @param request 知识库文档请求体
     * @return 更新后的知识库文档响应 DTO
     */
    @PutMapping("/{id}")
    public ApiResponse<KnowledgeDocResponse> update(
            @PathVariable UUID id,
            @Valid @RequestBody KnowledgeDocRequest request
    ) {
        return ApiResponse.ok(knowledgeAdminService.update(id, request));
    }

    /**
     * 删除知识库文档
     *
     * @param id 文档 ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    public ApiResponse<OperationResult> delete(@PathVariable UUID id) {
        knowledgeAdminService.delete(id);
        return ApiResponse.ok(OperationResult.deleted(id));
    }
}
