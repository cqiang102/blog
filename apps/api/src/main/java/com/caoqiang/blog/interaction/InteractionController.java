package com.caoqiang.blog.interaction;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.Map;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class InteractionController {

    private final InteractionService interactionService;

    public InteractionController(InteractionService interactionService) {
        this.interactionService = interactionService;
    }

    @GetMapping("/contents/{contentId}/comments")
    public ApiResponse<PageResponse<CommentResponse>> comments(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID contentId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        UUID userId = currentUser != null ? currentUser.id() : null;
        return ApiResponse.ok(interactionService.comments(contentId, page, size, userId));
    }

    @PostMapping("/contents/{contentId}/comments")
    public ApiResponse<CommentResponse> comment(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID contentId,
            @Valid @RequestBody CommentRequest request
    ) {
        return ApiResponse.ok(interactionService.comment(currentUser, contentId, request));
    }

    @DeleteMapping("/comments/{commentId}")
    public ApiResponse<Map<String, Object>> deleteComment(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID commentId
    ) {
        interactionService.deleteComment(currentUser, commentId);
        return ApiResponse.ok(Map.of("deleted", true, "commentId", commentId));
    }

    @PostMapping("/contents/{contentId}/likes")
    public ApiResponse<LikeStateResponse> like(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID contentId
    ) {
        return ApiResponse.ok(interactionService.like(currentUser, contentId));
    }

    @DeleteMapping("/contents/{contentId}/likes")
    public ApiResponse<LikeStateResponse> unlike(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID contentId
    ) {
        return ApiResponse.ok(interactionService.unlike(currentUser, contentId));
    }

    @PostMapping("/contents/{contentId}/views")
    public ApiResponse<ViewStateResponse> recordView(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID contentId,
            HttpServletRequest request
    ) {
        String clientIp = getClientIp(request);
        String userAgent = request.getHeader("User-Agent");
        return ApiResponse.ok(interactionService.recordView(currentUser, contentId, clientIp, userAgent));
    }

    private String getClientIp(HttpServletRequest request) {
        String ip = request.getHeader("X-Forwarded-For");
        if (ip != null && !ip.isEmpty()) {
            return ip.split(",")[0].trim();
        }
        ip = request.getHeader("X-Real-IP");
        if (ip != null && !ip.isEmpty()) {
            return ip;
        }
        return request.getRemoteAddr();
    }
}
