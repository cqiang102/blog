package com.caoqiang.blog.admin;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.content.TagAdminService;
import com.caoqiang.blog.content.TagRequest;
import com.caoqiang.blog.content.TagResponse;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/tags")
public class AdminTagController {

    private final TagAdminService tagAdminService;

    public AdminTagController(TagAdminService tagAdminService) {
        this.tagAdminService = tagAdminService;
    }

    @GetMapping
    public ApiResponse<List<TagResponse>> list() {
        return ApiResponse.ok(tagAdminService.list());
    }

    @PostMapping
    public ApiResponse<TagResponse> create(@Valid @RequestBody TagRequest request) {
        return ApiResponse.ok(tagAdminService.create(request));
    }

    @PutMapping("/{id}")
    public ApiResponse<TagResponse> update(@PathVariable UUID id, @Valid @RequestBody TagRequest request) {
        return ApiResponse.ok(tagAdminService.update(id, request));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Map<String, Object>> delete(@PathVariable UUID id) {
        tagAdminService.delete(id);
        return ApiResponse.ok(Map.of("deleted", true, "id", id));
    }
}
