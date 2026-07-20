package com.caoqiang.blog.audit;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.audit.domain.model.AuditLog;
import com.caoqiang.blog.audit.domain.repository.AuditLogRepository;
import com.caoqiang.blog.support.PostgresRepositoryIntegrationTest;
import jakarta.persistence.EntityManager;
import java.util.Map;
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
class AuditPersistenceIntegrationTest extends PostgresRepositoryIntegrationTest {

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private EntityManager entityManager;

    @Test
    void storesScalarActorIdAndKeepsAuditHistoryAfterUserDeletion() {
        UUID userId = UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO users (id, email, nickname, role, status, created_at, updated_at)
                VALUES (?, 'audit-admin@example.com', 'Audit Admin', 'ADMIN', 'ACTIVE', now(), now())
                """, userId);
        AuditLog saved = auditLogRepository.saveAndFlush(
                new AuditLog(userId, "UPDATE", "CONTENT", UUID.randomUUID(), Map.of("field", "title")));

        assertThat(auditLogRepository.findAll(
                        (Specification<AuditLog>) (root, query, cb) -> cb.equal(root.get("actorUserId"), userId)))
                .extracting(AuditLog::getId)
                .contains(saved.getId());

        jdbcTemplate.update("DELETE FROM users WHERE id = ?", userId);
        entityManager.clear();

        assertThat(auditLogRepository.findById(saved.getId()))
                .get()
                .extracting(AuditLog::getActorUserId)
                .isNull();
    }
}
