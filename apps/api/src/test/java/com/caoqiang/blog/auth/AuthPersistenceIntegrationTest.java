package com.caoqiang.blog.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import com.caoqiang.blog.auth.domain.model.RefreshToken;
import com.caoqiang.blog.auth.domain.repository.OAuthAccountRepository;
import com.caoqiang.blog.auth.domain.repository.RefreshTokenRepository;
import com.caoqiang.blog.support.PostgresRepositoryIntegrationTest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.junit.jupiter.Testcontainers;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
class AuthPersistenceIntegrationTest extends PostgresRepositoryIntegrationTest {

    @Autowired
    private OAuthAccountRepository oauthAccountRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void persistsAuthRecordsUsingScalarUserIdForeignKeys() {
        UUID userId = UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO users (id, email, nickname, role, status, created_at, updated_at)
                VALUES (?, 'auth-persistence@example.com', 'Auth Test', 'USER', 'ACTIVE', now(), now())
                """, userId);

        OAuthAccount account = oauthAccountRepository.saveAndFlush(
                new OAuthAccount(userId, OAuthProvider.GITHUB, "github-user-42", "octocat"));
        RefreshToken refreshToken = refreshTokenRepository.saveAndFlush(
                new RefreshToken(userId, "hashed-refresh-token", Instant.now().plus(7, ChronoUnit.DAYS)));

        assertThat(oauthAccountRepository.findByUserIdAndProvider(userId, OAuthProvider.GITHUB))
                .contains(account);
        assertThat(refreshTokenRepository.findByTokenHashAndRevokedAtIsNull("hashed-refresh-token"))
                .contains(refreshToken);
        assertThat(account.getUserId()).isEqualTo(userId);
        assertThat(refreshToken.getUserId()).isEqualTo(userId);
    }
}
