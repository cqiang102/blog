package com.caoqiang.blog.admin;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.interaction.AdminCommentResponse;
import com.caoqiang.blog.interaction.AdminCommentStatusRequest;
import com.caoqiang.blog.interaction.CommentAdminService;
import com.caoqiang.blog.interaction.CommentStatus;
import jakarta.validation.Valid;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/comments")
public class AdminCommentController {

    private final CommentAdminService commentAdminService;

    public AdminCommentController(CommentAdminService commentAdminService) {
        this.commentAdminService = commentAdminService;
    }

    @GetMapping
    public ApiResponse<PageResponse<AdminCommentResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) CommentStatus status,
            @RequestParam(required = false) UUID contentId,
            @RequestParam(required = false) UUID userId
    ) {
        return ApiResponse.ok(commentAdminService.list(page, size, status, contentId, userId));
    }

    @PutMapping("/{id}/status")
    public ApiResponse<AdminCommentResponse> setStatus(
            @PathVariable UUID id,
            @Valid @RequestBody AdminCommentStatusRequest request
    ) {
        return ApiResponse.ok(commentAdminService.setStatus(id, request.status()));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Map<String, Object>> delete(@PathVariable UUID id) {
        commentAdminService.delete(id);
        return ApiResponse.ok(Map.of("deleted", true, "id", id));
    }
}
