package com.caoqiang.blog.admin;

import com.caoqiang.blog.ai.KnowledgeAdminService;
import com.caoqiang.blog.ai.KnowledgeDocRequest;
import com.caoqiang.blog.ai.KnowledgeDocResponse;
import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import jakarta.validation.Valid;
import java.util.Map;
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

@RestController
@RequestMapping("/api/v1/admin/knowledge/docs")
public class AdminKnowledgeController {

    private final KnowledgeAdminService knowledgeAdminService;

    public AdminKnowledgeController(KnowledgeAdminService knowledgeAdminService) {
        this.knowledgeAdminService = knowledgeAdminService;
    }

    @GetMapping
    public ApiResponse<PageResponse<KnowledgeDocResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) Boolean enabled
    ) {
        return ApiResponse.ok(knowledgeAdminService.list(page, size, query, enabled));
    }

    @GetMapping("/{id}")
    public ApiResponse<KnowledgeDocResponse> detail(@PathVariable UUID id) {
        return ApiResponse.ok(knowledgeAdminService.detail(id));
    }

    @PostMapping
    public ApiResponse<KnowledgeDocResponse> create(@Valid @RequestBody KnowledgeDocRequest request) {
        return ApiResponse.ok(knowledgeAdminService.create(request));
    }

    @PutMapping("/{id}")
    public ApiResponse<KnowledgeDocResponse> update(
            @PathVariable UUID id,
            @Valid @RequestBody KnowledgeDocRequest request
    ) {
        return ApiResponse.ok(knowledgeAdminService.update(id, request));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Map<String, Object>> delete(@PathVariable UUID id) {
        knowledgeAdminService.delete(id);
        return ApiResponse.ok(Map.of("deleted", true, "id", id));
    }
}
