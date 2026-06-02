package com.caoqiang.blog.auth;

import com.caoqiang.blog.user.UserProfileResponse;
import java.time.Instant;

public record AuthTokenResponse(
        String accessToken,
        String refreshToken,
        Instant expiresAt,
        UserProfileResponse user
) {
}
