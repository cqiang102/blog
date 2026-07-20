package com.caoqiang.blog.auth.application.dto;

import com.caoqiang.blog.user.application.api.UserProfileResponse;
import java.time.Instant;

/**
 * 服务端内部签发结果。刷新令牌只允许写入 HttpOnly Cookie，不进入 JSON 响应。
 */
public record IssuedAuthSession(String accessToken, String refreshToken, Instant expiresAt, UserProfileResponse user) {
    public AuthTokenResponse toResponse() {
        return new AuthTokenResponse(accessToken, expiresAt, user);
    }
}
