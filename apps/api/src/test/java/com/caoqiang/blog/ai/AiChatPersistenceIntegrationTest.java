package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.ai.chat.domain.model.AiDailyQuota;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatSessionRepository;
import com.caoqiang.blog.ai.chat.domain.repository.AiDailyQuotaRepository;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
class AiChatPersistenceIntegrationTest {

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
    private AiChatSessionRepository sessionRepository;
    @Autowired
    private AiDailyQuotaRepository quotaRepository;
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void persistsAiOwnershipAsScalarUserIdsAndKeepsIdentitySearch() {
        UUID userId = UUID.randomUUID();
        jdbcTemplate.update(
                """
                INSERT INTO users (id, email, nickname, role, status, created_at, updated_at)
                VALUES (?, 'ai-reader@example.com', 'AI Reader', 'USER', 'ACTIVE', now(), now())
                """,
                userId
        );

        AiChatSession session = sessionRepository.saveAndFlush(new AiChatSession(userId, "Architecture"));
        LocalDate quotaDate = LocalDate.of(2026, 7, 13);
        AiDailyQuota quota = new AiDailyQuota(userId, quotaDate);
        quota.increase();
        quotaRepository.saveAndFlush(quota);

        assertThat(sessionRepository.findByIdAndUserIdAndDeletedFalse(session.getId(), userId))
                .contains(session);
        assertThat(sessionRepository.findForUpdate(session.getId(), userId)).contains(session);
        assertThat(sessionRepository.findAll((Specification<AiChatSession>) (root, query, cb) ->
                cb.equal(root.get("userId"), userId))).contains(session);
        assertThat(quotaRepository.findByUserIdAndQuotaDate(userId, quotaDate))
                .get()
                .satisfies(storedQuota -> {
                    assertThat(storedQuota.getUserId()).isEqualTo(userId);
                    assertThat(storedQuota.getQuotaDate()).isEqualTo(quotaDate);
                    assertThat(storedQuota.getQuestionCount()).isEqualTo(1);
                });
        assertThat(userRepository.findIdsMatchingIdentity("reader")).containsExactly(userId);
        assertThat(session.getUserId()).isEqualTo(userId);
        assertThat(quota.getUserId()).isEqualTo(userId);
    }
}
