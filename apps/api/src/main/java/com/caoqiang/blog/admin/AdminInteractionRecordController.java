package com.caoqiang.blog.admin;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.interaction.AdminLikeResponse;
import com.caoqiang.blog.interaction.AdminViewRecordResponse;
import com.caoqiang.blog.interaction.InteractionAdminService;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin")
public class AdminInteractionRecordController {

    private final InteractionAdminService interactionAdminService;

    public AdminInteractionRecordController(InteractionAdminService interactionAdminService) {
        this.interactionAdminService = interactionAdminService;
    }

    @GetMapping("/likes")
    public ApiResponse<PageResponse<AdminLikeResponse>> likes(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) UUID contentId,
            @RequestParam(required = false) UUID userId
    ) {
        return ApiResponse.ok(interactionAdminService.likes(page, size, contentId, userId));
    }

    @DeleteMapping("/likes/{id}")
    public ApiResponse<Map<String, Object>> deleteLike(@PathVariable UUID id) {
        interactionAdminService.deleteLike(id);
        return ApiResponse.ok(Map.of("deleted", true, "id", id));
    }

    @GetMapping("/views")
    public ApiResponse<PageResponse<AdminViewRecordResponse>> views(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) UUID contentId,
            @RequestParam(required = false) UUID userId
    ) {
        return ApiResponse.ok(interactionAdminService.views(page, size, contentId, userId));
    }

    @DeleteMapping("/views/{id}")
    public ApiResponse<Map<String, Object>> deleteView(@PathVariable UUID id) {
        interactionAdminService.deleteView(id);
        return ApiResponse.ok(Map.of("deleted", true, "id", id));
    }
}
