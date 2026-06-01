package com.caoqiang.blog.interaction;

import com.caoqiang.blog.common.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class InteractionController {

    @PostMapping("/contents/{contentId}/comments")
    public ApiResponse<Map<String, Object>> comment(@PathVariable UUID contentId, @Valid @RequestBody CommentRequest request) {
        return ApiResponse.ok(Map.of("contentId", contentId, "commentId", UUID.randomUUID(), "body", request.body()));
    }

    @DeleteMapping("/comments/{commentId}")
    public ApiResponse<Map<String, Object>> deleteComment(@PathVariable UUID commentId) {
        return ApiResponse.ok(Map.of("deleted", true, "commentId", commentId));
    }

    @PostMapping("/contents/{contentId}/likes")
    public ApiResponse<Map<String, Object>> like(@PathVariable UUID contentId) {
        return ApiResponse.ok(Map.of("contentId", contentId, "liked", true));
    }

    @DeleteMapping("/contents/{contentId}/likes")
    public ApiResponse<Map<String, Object>> unlike(@PathVariable UUID contentId) {
        return ApiResponse.ok(Map.of("contentId", contentId, "liked", false));
    }

    @PostMapping("/contents/{contentId}/views")
    public ApiResponse<Map<String, Object>> recordView(@PathVariable UUID contentId) {
        return ApiResponse.ok(Map.of("contentId", contentId, "recorded", true));
    }

    public record CommentRequest(@NotBlank @Size(max = 2000) String body) {
    }
}
