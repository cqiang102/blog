package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import java.util.List;
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

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
class KnowledgeChunkRepositoryIntegrationTest {

    private static final DockerImageName PGVECTOR_IMAGE = DockerImageName
            .parse("pgvector/pgvector:pg18")
            .asCompatibleSubstituteFor("postgres");

    @Container
    private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(PGVECTOR_IMAGE)
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
    private KnowledgeChunkRepository repository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void bindsPgvectorParameterAndReturnsNearestEnabledKnowledgeChunk() {
        UUID docId = UUID.randomUUID();
        UUID chunkId = UUID.randomUUID();
        String embedding = unitVector();

        jdbcTemplate.update(
                """
                INSERT INTO knowledge_docs
                    (id, title, source_type, body, enabled, created_at, updated_at)
                VALUES (?, 'Repository test', 'MANUAL', 'Java backend', true, now(), now())
                """,
                docId
        );
        jdbcTemplate.update(
                """
                INSERT INTO knowledge_chunks
                    (id, doc_id, chunk_index, content, embedding, created_at)
                VALUES (?, ?, 0, 'Java backend', CAST(? AS vector), now())
                """,
                chunkId,
                docId,
                embedding
        );

        List<Object[]> results = repository.findSimilarChunks(embedding, 5);

        assertThat(results).singleElement().satisfies(row -> {
            assertThat(row[0]).isEqualTo(chunkId);
            assertThat(row[1]).isEqualTo(docId);
            assertThat(((Number) row[6]).doubleValue()).isEqualTo(1.0);
        });
    }

    private String unitVector() {
        StringBuilder vector = new StringBuilder("[1");
        for (int index = 1; index < 768; index++) {
            vector.append(",0");
        }
        return vector.append(']').toString();
    }
}
