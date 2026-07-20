package com.caoqiang.blog.user.application.port;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * User-module view of linked OAuth accounts.
 *
 * <p>The auth module owns OAuth persistence and implements this port. The user
 * module only needs a stable read model and an unlink command.</p>
 */
public interface OAuthAccountPort {

    List<LinkedOAuthAccount> findByUserId(UUID userId);

    boolean remove(UUID userId, String provider);

    record LinkedOAuthAccount(String provider, String providerUsername, Instant createdAt) {}
}
