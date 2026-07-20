package com.caoqiang.blog.user.application.api;

import com.caoqiang.blog.shared.model.Role;
import java.util.UUID;

/**
 * Immutable user snapshot exposed to authentication workflows.
 */
public record IdentityUser(
        UUID id,
        String email,
        String nickname,
        String avatarUrl,
        String bio,
        String blogUrl,
        String passwordHash,
        Role role,
        boolean active) {

    public boolean hasPassword() {
        return passwordHash != null;
    }
}
