package com.caoqiang.blog.user;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/me")
public class ProfileController {

    @GetMapping
    public ApiResponse<UserProfile> me() {
        return ApiResponse.ok(sampleProfile());
    }

    @PutMapping
    public ApiResponse<UserProfile> update(@Valid @RequestBody UpdateProfileRequest request) {
        return ApiResponse.ok(new UserProfile(
                UUID.randomUUID(),
                request.email(),
                request.nickname(),
                request.avatarUrl(),
                request.bio(),
                request.blogUrl()
        ));
    }

    @GetMapping("/comments")
    public ApiResponse<PageResponse<UserRecord>> comments() {
        return ApiResponse.ok(sampleRecords("COMMENT"));
    }

    @GetMapping("/likes")
    public ApiResponse<PageResponse<UserRecord>> likes() {
        return ApiResponse.ok(sampleRecords("LIKE"));
    }

    @GetMapping("/views")
    public ApiResponse<PageResponse<UserRecord>> views() {
        return ApiResponse.ok(sampleRecords("VIEW"));
    }

    private UserProfile sampleProfile() {
        return new UserProfile(UUID.randomUUID(), "me@example.com", "站长", null, "写代码，也记录生活。", "https://example.com");
    }

    private PageResponse<UserRecord> sampleRecords(String type) {
        return new PageResponse<>(List.of(new UserRecord(UUID.randomUUID(), type, "示例记录", Instant.now())), 0, 10, 1);
    }

    public record UpdateProfileRequest(
            @Size(max = 80) String nickname,
            String avatarUrl,
            @Size(max = 500) String bio,
            String blogUrl,
            @Email String email
    ) {
    }

    public record UserProfile(UUID id, String email, String nickname, String avatarUrl, String bio, String blogUrl) {
    }

    public record UserRecord(UUID id, String type, String title, Instant createdAt) {
    }
}
