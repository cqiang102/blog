package com.caoqiang.blog.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.caoqiang.blog.auth.application.dto.JwtClaims;
import com.caoqiang.blog.auth.application.service.JwtService;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class JwtServiceTest {

    private static final Instant NOW = Instant.parse("2026-06-01T00:00:00Z");

    @Test
    void createsAndParsesSignedAccessToken() {
        JwtService jwtService = jwtService(Clock.fixed(NOW, ZoneOffset.UTC), 30);
        IdentityUser user = identityUser();

        JwtService.JwtToken token = jwtService.createAccessToken(user);
        JwtClaims claims = jwtService.parseAccessToken(token.value());

        assertThat(claims.userId()).isEqualTo(user.id());
        assertThat(claims.email()).isEqualTo("me@example.com");
        assertThat(claims.nickname()).isEqualTo("站长");
        assertThat(claims.role()).isEqualTo(Role.USER);
        assertThat(claims.expiresAt()).isEqualTo(NOW.plusSeconds(1800));
    }

    @Test
    void rejectsTamperedToken() {
        JwtService jwtService = jwtService(Clock.fixed(NOW, ZoneOffset.UTC), 30);
        IdentityUser user = identityUser();
        String token = jwtService.createAccessToken(user).value();
        int signatureStart = token.lastIndexOf('.') + 1;
        char original = token.charAt(signatureStart);
        StringBuilder tamperedToken = new StringBuilder(token);
        tamperedToken.setCharAt(signatureStart, original == 'A' ? 'B' : 'A');

        assertThatThrownBy(() -> jwtService.parseAccessToken(tamperedToken.toString()))
                .isInstanceOf(IllegalArgumentException.class);
    }

    private JwtService jwtService(Clock clock, int accessTokenMinutes) {
        BlogProperties blogProperties = new BlogProperties();
        blogProperties.getSecurity().setJwtSecret("unit-test-secret-with-enough-length");
        blogProperties.getSecurity().setAccessTokenMinutes(accessTokenMinutes);
        return new JwtService(blogProperties, clock);
    }

    private IdentityUser identityUser() {
        return new IdentityUser(UUID.randomUUID(), "me@example.com", "站长", null, null, null, "hash", Role.USER, true);
    }
}
