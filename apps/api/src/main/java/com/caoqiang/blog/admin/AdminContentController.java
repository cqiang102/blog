package com.caoqiang.blog.admin;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.content.AdminContentRequest;
import com.caoqiang.blog.content.AdminContentResponse;
import com.caoqiang.blog.content.ContentAdminService;
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
@RequestMapping("/api/v1/admin/contents")
public class AdminContentController {

    private final ContentAdminService contentAdminService;

    public AdminContentController(ContentAdminService contentAdminService) {
        this.contentAdminService = contentAdminService;
    }

    @GetMapping
    public ApiResponse<PageResponse<AdminContentResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return ApiResponse.ok(contentAdminService.list(page, size));
    }

    @GetMapping("/{id}")
    public ApiResponse<AdminContentResponse> detail(@PathVariable UUID id) {
        return ApiResponse.ok(contentAdminService.detail(id));
    }

    @PostMapping
    public ApiResponse<AdminContentResponse> create(@Valid @RequestBody AdminContentRequest request) {
        return ApiResponse.ok(contentAdminService.create(request));
    }

    @PutMapping("/{id}")
    public ApiResponse<AdminContentResponse> update(
            @PathVariable UUID id,
            @Valid @RequestBody AdminContentRequest request
    ) {
        return ApiResponse.ok(contentAdminService.update(id, request));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Map<String, Object>> archive(@PathVariable UUID id) {
        contentAdminService.archive(id);
        return ApiResponse.ok(Map.of("archived", true, "id", id));
    }
}
