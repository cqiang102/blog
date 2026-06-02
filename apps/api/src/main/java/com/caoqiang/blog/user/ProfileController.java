package com.caoqiang.blog.user;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.interaction.InteractionService;
import com.caoqiang.blog.interaction.UserActivityResponse;
import jakarta.validation.Valid;
import java.util.Map;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/me")
public class ProfileController {

    private final ProfileService profileService;
    private final InteractionService interactionService;

    public ProfileController(ProfileService profileService, InteractionService interactionService) {
        this.profileService = profileService;
        this.interactionService = interactionService;
    }

    @GetMapping
    public ApiResponse<UserProfileResponse> me(@AuthenticationPrincipal AuthenticatedUser currentUser) {
        return ApiResponse.ok(profileService.me(currentUser));
    }

    @PutMapping
    public ApiResponse<UserProfileResponse> update(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @Valid @RequestBody UpdateProfileRequest request
    ) {
        return ApiResponse.ok(profileService.update(currentUser, request));
    }

    @GetMapping("/comments")
    public ApiResponse<PageResponse<UserActivityResponse>> comments(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return ApiResponse.ok(interactionService.myComments(currentUser, page, size));
    }

    @GetMapping("/likes")
    public ApiResponse<PageResponse<UserActivityResponse>> likes(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return ApiResponse.ok(interactionService.myLikes(currentUser, page, size));
    }

    @GetMapping("/views")
    public ApiResponse<PageResponse<UserActivityResponse>> views(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return ApiResponse.ok(interactionService.myViews(currentUser, page, size));
    }

    @DeleteMapping("/comments/{commentId}")
    public ApiResponse<Map<String, Object>> deleteMyComment(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID commentId
    ) {
        interactionService.deleteComment(currentUser, commentId);
        return ApiResponse.ok(Map.of("deleted", true, "commentId", commentId));
    }

    @DeleteMapping("/likes/{contentId}")
    public ApiResponse<Map<String, Object>> deleteMyLike(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID contentId
    ) {
        interactionService.deleteMyLike(currentUser, contentId);
        return ApiResponse.ok(Map.of("deleted", true, "contentId", contentId));
    }

    @DeleteMapping("/views/{viewRecordId}")
    public ApiResponse<Map<String, Object>> deleteMyView(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID viewRecordId
    ) {
        interactionService.deleteMyView(currentUser, viewRecordId);
        return ApiResponse.ok(Map.of("deleted", true, "viewRecordId", viewRecordId));
    }
}
