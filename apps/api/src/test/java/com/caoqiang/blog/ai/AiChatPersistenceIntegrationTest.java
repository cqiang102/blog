package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.ai.chat.domain.model.AiDailyQuota;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatSessionRepository;
import com.caoqiang.blog.ai.chat.domain.repository.AiDailyQuotaRepository;
import com.caoqiang.blog.support.PostgresRepositoryIntegrationTest;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.junit.jupiter.Testcontainers;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
class AiChatPersistenceIntegrationTest extends PostgresRepositoryIntegrationTest {

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
        jdbcTemplate.update("""
                INSERT INTO users (id, email, nickname, role, status, created_at, updated_at)
                VALUES (?, 'ai-reader@example.com', 'AI Reader', 'USER', 'ACTIVE', now(), now())
                """, userId);

        AiChatSession session = sessionRepository.saveAndFlush(new AiChatSession(userId, "Architecture"));
        LocalDate quotaDate = LocalDate.of(2026, 7, 13);
        AiDailyQuota quota = new AiDailyQuota(userId, quotaDate);
        quota.increase();
        quotaRepository.saveAndFlush(quota);

        assertThat(sessionRepository.findByIdAndUserIdAndDeletedFalse(session.getId(), userId))
                .contains(session);
        assertThat(sessionRepository.findForUpdate(session.getId(), userId)).contains(session);
        assertThat(sessionRepository.findAll(
                        (Specification<AiChatSession>) (root, query, cb) -> cb.equal(root.get("userId"), userId)))
                .contains(session);
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
