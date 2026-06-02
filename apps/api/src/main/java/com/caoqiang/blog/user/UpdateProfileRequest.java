package com.caoqiang.blog.user;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;

public record UpdateProfileRequest(
        @Size(max = 80) String nickname,
        String avatarUrl,
        @Size(max = 500) String bio,
        String blogUrl,
        @Email String email
) {
}
