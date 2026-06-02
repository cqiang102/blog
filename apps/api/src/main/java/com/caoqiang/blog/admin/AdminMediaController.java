package com.caoqiang.blog.admin;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.content.AdminContentResponse;
import com.caoqiang.blog.content.AdminMediaRequest;
import com.caoqiang.blog.content.AdminMediaResponse;
import com.caoqiang.blog.content.MediaAdminService;
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
@RequestMapping("/api/v1/admin")
public class AdminMediaController {

    private final MediaAdminService mediaAdminService;

    public AdminMediaController(MediaAdminService mediaAdminService) {
        this.mediaAdminService = mediaAdminService;
    }

    @GetMapping("/media-assets")
    public ApiResponse<PageResponse<AdminMediaResponse>> list(
            @RequestParam(required = false) UUID contentId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        return ApiResponse.ok(mediaAdminService.list(contentId, page, size));
    }

    @PostMapping("/media-assets")
    public ApiResponse<AdminMediaResponse> create(@Valid @RequestBody AdminMediaRequest request) {
        return ApiResponse.ok(mediaAdminService.create(request));
    }

    @PutMapping("/media-assets/{id}")
    public ApiResponse<AdminMediaResponse> update(@PathVariable UUID id, @Valid @RequestBody AdminMediaRequest request) {
        return ApiResponse.ok(mediaAdminService.update(id, request));
    }

    @DeleteMapping("/media-assets/{id}")
    public ApiResponse<Map<String, Object>> delete(@PathVariable UUID id) {
        mediaAdminService.delete(id);
        return ApiResponse.ok(Map.of("deleted", true, "id", id));
    }

    @PutMapping("/contents/{contentId}/cover/{mediaId}")
    public ApiResponse<AdminContentResponse> setCover(@PathVariable UUID contentId, @PathVariable UUID mediaId) {
        return ApiResponse.ok(mediaAdminService.setCover(contentId, mediaId));
    }
}
