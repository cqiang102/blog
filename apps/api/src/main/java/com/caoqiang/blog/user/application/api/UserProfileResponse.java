package com.caoqiang.blog.user.application.api;

import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.domain.model.User;
import java.util.UUID;

/** Public non-sensitive user profile returned by user and auth surfaces. */
public record UserProfileResponse(
        UUID id,
        String email,
        String nickname,
        String avatarUrl,
        String bio,
        String blogUrl,
        Role role,
        boolean hasPassword
) {

    public static UserProfileResponse from(User user) {
        return new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getAvatarUrl(),
                user.getBio(),
                user.getBlogUrl(),
                user.getRole(),
                user.getPasswordHash() != null
        );
    }

    public static UserProfileResponse from(User user, String presignedAvatarUrl) {
        return new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                presignedAvatarUrl,
                user.getBio(),
                user.getBlogUrl(),
                user.getRole(),
                user.getPasswordHash() != null
        );
    }

    public static UserProfileResponse from(IdentityUser user, String presignedAvatarUrl) {
        return new UserProfileResponse(
                user.id(),
                user.email(),
                user.nickname(),
                presignedAvatarUrl,
                user.bio(),
                user.blogUrl(),
                user.role(),
                user.hasPassword()
        );
    }
}
