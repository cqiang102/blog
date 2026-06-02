package com.caoqiang.blog.auth;

import java.time.Instant;
import java.util.UUID;

public record JwtClaims(UUID userId, String email, String nickname, Role role, Instant expiresAt) {
}
