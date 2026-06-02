package com.caoqiang.blog.user;

import com.caoqiang.blog.auth.Role;
import java.time.Instant;
import java.util.UUID;

public record AdminUserResponse(
        UUID id,
        String email,
        String nickname,
        String avatarUrl,
        String bio,
        String blogUrl,
        Role role,
        UserStatus status,
        Instant createdAt,
        Instant updatedAt
) {

    public static AdminUserResponse from(User user) {
        return new AdminUserResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getAvatarUrl(),
                user.getBio(),
                user.getBlogUrl(),
                user.getRole(),
                user.getStatus(),
                user.getCreatedAt(),
                user.getUpdatedAt()
        );
    }
}
