package com.caoqiang.blog.auth;

import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import com.caoqiang.blog.auth.domain.model.RefreshToken;
import com.caoqiang.blog.auth.domain.repository.OAuthAccountRepository;
import com.caoqiang.blog.auth.domain.repository.RefreshTokenRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
class AuthPersistenceIntegrationTest {

    private static final DockerImageName POSTGRES_IMAGE = DockerImageName
            .parse("pgvector/pgvector:pg18")
            .asCompatibleSubstituteFor("postgres");

    @Container
    private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(POSTGRES_IMAGE)
            .withDatabaseName("blog")
            .withUsername("blog")
            .withPassword("blog");

    @DynamicPropertySource
    static void databaseProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.jpa.hibernate.ddl-auto", () -> "validate");
        registry.add("spring.flyway.enabled", () -> "true");
    }

    @Autowired
    private OAuthAccountRepository oauthAccountRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void persistsAuthRecordsUsingScalarUserIdForeignKeys() {
        UUID userId = UUID.randomUUID();
        jdbcTemplate.update(
                """
                INSERT INTO users (id, email, nickname, role, status, created_at, updated_at)
                VALUES (?, 'auth-persistence@example.com', 'Auth Test', 'USER', 'ACTIVE', now(), now())
                """,
                userId
        );

        OAuthAccount account = oauthAccountRepository.saveAndFlush(
                new OAuthAccount(userId, OAuthProvider.GITHUB, "github-user-42", "octocat")
        );
        RefreshToken refreshToken = refreshTokenRepository.saveAndFlush(
                new RefreshToken(
                        userId,
                        "hashed-refresh-token",
                        Instant.now().plus(7, ChronoUnit.DAYS)
                )
        );

        assertThat(oauthAccountRepository.findByUserIdAndProvider(userId, OAuthProvider.GITHUB))
                .contains(account);
        assertThat(refreshTokenRepository.findByTokenHashAndRevokedAtIsNull("hashed-refresh-token"))
                .contains(refreshToken);
        assertThat(account.getUserId()).isEqualTo(userId);
        assertThat(refreshToken.getUserId()).isEqualTo(userId);
    }
}
