package com.caoqiang.blog.auth;

import com.caoqiang.blog.auth.application.service.JwtService;
import com.caoqiang.blog.auth.application.dto.JwtClaims;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.domain.model.User;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class JwtServiceTest {

    private static final Instant NOW = Instant.parse("2026-06-01T00:00:00Z");

    @Test
    void createsAndParsesSignedAccessToken() {
        JwtService jwtService = jwtService(Clock.fixed(NOW, ZoneOffset.UTC), 30);
        User user = User.register("me@example.com", "hash", "站长");

        JwtService.JwtToken token = jwtService.createAccessToken(user);
        JwtClaims claims = jwtService.parseAccessToken(token.value());

        assertThat(claims.userId()).isEqualTo(user.getId());
        assertThat(claims.email()).isEqualTo("me@example.com");
        assertThat(claims.nickname()).isEqualTo("站长");
        assertThat(claims.role()).isEqualTo(Role.USER);
        assertThat(claims.expiresAt()).isEqualTo(NOW.plusSeconds(1800));
    }

    @Test
    void rejectsTamperedToken() {
        JwtService jwtService = jwtService(Clock.fixed(NOW, ZoneOffset.UTC), 30);
        User user = User.register("me@example.com", "hash", "站长");
        String token = jwtService.createAccessToken(user).value();

        assertThatThrownBy(() -> jwtService.parseAccessToken(token.substring(0, token.length() - 2) + "xx"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void validatesOnlyUnexpiredOAuthLoginState() {
        JwtService issuer = jwtService(Clock.fixed(NOW, ZoneOffset.UTC), 30);
        String state = issuer.createOAuthLoginState();

        assertThat(issuer.isValidOAuthLoginState(state)).isTrue();

        JwtService expiredValidator = jwtService(
                Clock.fixed(NOW.plusSeconds(301), ZoneOffset.UTC),
                30
        );
        assertThat(expiredValidator.isValidOAuthLoginState(state)).isFalse();
    }

    private JwtService jwtService(Clock clock, int accessTokenMinutes) {
        BlogProperties blogProperties = new BlogProperties();
        blogProperties.getSecurity().setJwtSecret("unit-test-secret-with-enough-length");
        blogProperties.getSecurity().setAccessTokenMinutes(accessTokenMinutes);
        return new JwtService(blogProperties, clock);
    }
}
