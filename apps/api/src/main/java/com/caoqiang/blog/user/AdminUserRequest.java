package com.caoqiang.blog.user;

import com.caoqiang.blog.auth.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record AdminUserRequest(
        @NotBlank @Email @Size(max = 320) String email,
        @NotBlank @Size(max = 80) String nickname,
        String avatarUrl,
        @Size(max = 2000) String bio,
        String blogUrl,
        @NotNull Role role,
        @NotNull UserStatus status
) {
}
