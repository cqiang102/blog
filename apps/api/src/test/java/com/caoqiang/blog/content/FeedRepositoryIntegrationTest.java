package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.ContentRepository.FeedEntryProjection;
import com.caoqiang.blog.support.PostgresRepositoryIntegrationTest;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
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
class FeedRepositoryIntegrationTest extends PostgresRepositoryIntegrationTest {

    private static final Instant NOW = Instant.parse("2030-01-01T00:00:00Z");

    @Autowired
    private ContentRepository repository;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void limitsToLatest20PublicArticlesWithDeterministicTiesAndExcludesHiddenContent() {
        // Isolate the feed from Flyway's seeded sample posts within this rolled-back transaction.
        jdbc.update("UPDATE contents SET status = 'DRAFT'");
        List<UUID> expected = new ArrayList<>();
        for (int index = 1; index <= 22; index++) {
            UUID id = new UUID(0, index);
            insert(id, "ARTICLE", "PUBLISHED", NOW.minusSeconds(22 - index), false);
            expected.addFirst(id);
        }
        UUID tie = new UUID(0, 23);
        insert(tie, "ARTICLE", "PUBLISHED", NOW, false);
        expected.addFirst(tie);
        insert(UUID.randomUUID(), "ARTICLE", "DRAFT", NOW, false);
        insert(UUID.randomUUID(), "ARTICLE", "ARCHIVED", NOW, false);
        insert(UUID.randomUUID(), "ARTICLE", "PUBLISHED", NOW, true);
        insert(UUID.randomUUID(), "ARTICLE", "PUBLISHED", NOW.plusSeconds(1), false);
        insert(UUID.randomUUID(), "ARTICLE", "PUBLISHED", null, false);
        insert(UUID.randomUUID(), "IMAGE", "PUBLISHED", NOW, false);
        insert(UUID.randomUUID(), "VIDEO", "PUBLISHED", NOW, false);

        var entries =
                repository
                        .findTop20ByTypeAndStatusAndDeletedAtIsNullAndPublishedAtLessThanEqualOrderByPublishedAtDescIdDesc(
                                ContentType.ARTICLE, ContentStatus.PUBLISHED, NOW);

        assertThat(entries).extracting(FeedEntryProjection::getId).containsExactlyElementsOf(expected.subList(0, 20));
        assertThat(entries.getFirst().getTitle()).isEqualTo("订阅文章");
        assertThat(entries.getFirst().getSummary()).isEqualTo("文章摘要");
        assertThat(entries.getFirst().getPublishedAt()).isEqualTo(NOW);
        assertThat(entries.getFirst().getUpdatedAt()).isEqualTo(NOW);
    }

    private void insert(UUID id, String type, String status, Instant published, boolean deleted) {
        jdbc.update(
                """
                INSERT INTO contents
                    (id, title, slug, type, status, summary, body_markdown, published_at, updated_at, deleted_at)
                VALUES (?, '订阅文章', ?, ?, ?, '文章摘要', '正文不应出现在摘要订阅中', ?, ?, ?)
                """,
                id,
                id.toString(),
                type,
                status,
                published == null ? null : Timestamp.from(published),
                Timestamp.from(NOW),
                deleted ? Timestamp.from(NOW) : null);
    }
}
