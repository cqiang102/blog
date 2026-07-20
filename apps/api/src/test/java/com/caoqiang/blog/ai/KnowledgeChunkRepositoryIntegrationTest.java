package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.ai.knowledge.domain.model.FailedEmbeddingChunk;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import com.caoqiang.blog.support.PostgresRepositoryIntegrationTest;
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
class KnowledgeChunkRepositoryIntegrationTest extends PostgresRepositoryIntegrationTest {

    @Autowired
    private KnowledgeChunkRepository repository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void bindsPgvectorParameterAndReturnsNearestEnabledKnowledgeChunk() {
        UUID docId = UUID.randomUUID();
        UUID chunkId = UUID.randomUUID();
        String embedding = unitVector();

        jdbcTemplate.update("""
                INSERT INTO knowledge_docs
                    (id, title, source_type, body, enabled, created_at, updated_at)
                VALUES (?, 'Repository test', 'MANUAL', 'Java backend', true, now(), now())
                """, docId);
        jdbcTemplate.update("""
                INSERT INTO knowledge_chunks
                    (id, doc_id, chunk_index, content, embedding, created_at)
                VALUES (?, ?, 0, 'Java backend', CAST(? AS vector), now())
                """, chunkId, docId, embedding);

        List<Object[]> results = repository.findSimilarChunks(embedding, 5);

        assertThat(results).singleElement().satisfies(row -> {
            assertThat(row[0]).isEqualTo(chunkId);
            assertThat(row[1]).isEqualTo(docId);
            assertThat(((Number) row[6]).doubleValue()).isEqualTo(1.0);
        });
    }

    @Test
    void pagesFailedCandidatesAndAppliesOnlyCurrentFailureResults() {
        UUID docId = UUID.randomUUID();
        UUID firstId = new UUID(0, 1);
        UUID secondId = new UUID(0, 2);
        jdbcTemplate.update("""
                INSERT INTO knowledge_docs
                    (id, title, source_type, body, enabled, created_at, updated_at)
                VALUES (?, 'Reindex test', 'MANUAL', 'Body', true, now(), now())
                """, docId);
        insertFailedChunk(firstId, docId, 0, "first");
        insertFailedChunk(secondId, docId, 1, "second");

        List<FailedEmbeddingChunk> firstPage = repository.findFailedEmbeddingCandidates(1);
        List<FailedEmbeddingChunk> secondPage = repository.findFailedEmbeddingCandidatesAfter(firstId, 1);

        assertThat(firstPage).singleElement().satisfies(candidate -> {
            assertThat(candidate.getId()).isEqualTo(firstId);
            assertThat(candidate.getContent()).isEqualTo("first");
        });
        assertThat(secondPage)
                .singleElement()
                .extracting(FailedEmbeddingChunk::getId)
                .isEqualTo(secondId);

        assertThat(repository.updateEmbeddingIfContentMatches(firstId, "first", unitVector()))
                .isEqualTo(1);
        assertThat(repository.updateEmbeddingFailureIfContentMatches(
                        firstId, "first", "{\"error\":\"embedding_generation_failed\",\"reindex_failed\":true}"))
                .isZero();
        assertThat(repository.updateEmbeddingIfContentMatches(secondId, "stale content", unitVector()))
                .isZero();

        assertThat(jdbcTemplate.queryForObject(
                        "SELECT metadata IS NULL FROM knowledge_chunks WHERE id = ?", Boolean.class, firstId))
                .isTrue();
    }

    @Test
    void scheduledRetryOrdersByOldestFailureTimestamp() {
        UUID docId = UUID.randomUUID();
        UUID lowerId = new UUID(0, 1);
        UUID higherId = new UUID(0, 2);
        jdbcTemplate.update("""
                INSERT INTO knowledge_docs
                    (id, title, source_type, body, enabled, created_at, updated_at)
                VALUES (?, 'Retry order', 'MANUAL', 'Body', true, now(), now())
                """, docId);
        insertFailedChunk(
                lowerId,
                docId,
                0,
                "recent",
                "{\"error\":\"embedding_generation_failed\",\"timestamp\":\"2026-06-26T08:00:00Z\"}");
        insertFailedChunk(
                higherId,
                docId,
                1,
                "old",
                "{\"error\":\"embedding_generation_failed\",\"timestamp\":\"2026-06-25T08:00:00Z\"}");

        List<FailedEmbeddingChunk> candidates = repository.findFailedEmbeddingCandidatesForScheduledRetry(1);

        assertThat(candidates)
                .singleElement()
                .extracting(FailedEmbeddingChunk::getId)
                .isEqualTo(higherId);
    }

    @Test
    void findsDurableSourcesWhoseIndexEventWasLost() {
        UUID documentId = UUID.randomUUID();
        UUID disabledDocumentId = UUID.randomUUID();
        UUID disabledDocumentChunkId = UUID.randomUUID();
        UUID publishedContentId = UUID.randomUUID();
        UUID archivedContentId = UUID.randomUUID();
        UUID archivedChunkId = UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO knowledge_docs
                    (id, title, source_type, body, enabled, created_at, updated_at)
                VALUES (?, 'Missing index', 'MANUAL', 'Body', true, now() - interval '1 minute', now())
                """, documentId);
        jdbcTemplate.update("""
                INSERT INTO knowledge_docs
                    (id, title, source_type, body, enabled, created_at, updated_at)
                VALUES (?, 'Disabled', 'MANUAL', 'Body', false, now() - interval '1 minute', now())
                """, disabledDocumentId);
        jdbcTemplate.update("""
                INSERT INTO knowledge_chunks
                    (id, doc_id, chunk_index, content, created_at)
                VALUES (?, ?, 0, 'stale disabled chunk', now())
                """, disabledDocumentChunkId, disabledDocumentId);
        insertContent(publishedContentId, "PUBLISHED");
        insertContent(archivedContentId, "ARCHIVED");
        jdbcTemplate.update("""
                INSERT INTO knowledge_chunks
                    (id, content_id, chunk_index, content, created_at)
                VALUES (?, ?, 0, 'stale archived chunk', now())
                """, archivedChunkId, archivedContentId);

        assertThat(repository.findDocumentIdsNeedingIndex(10)).contains(documentId);
        assertThat(repository.findDocumentIdsNeedingIndexDeletion(10)).contains(disabledDocumentId);
        assertThat(repository.findContentIdsNeedingIndex(10)).contains(publishedContentId);
        assertThat(repository.findContentIdsNeedingIndexDeletion(10)).contains(archivedContentId);
    }

    private void insertFailedChunk(UUID chunkId, UUID docId, int index, String content) {
        insertFailedChunk(chunkId, docId, index, content, "{\"error\":\"embedding_generation_failed\"}");
    }

    private void insertFailedChunk(UUID chunkId, UUID docId, int index, String content, String metadata) {
        jdbcTemplate.update("""
                INSERT INTO knowledge_chunks
                    (id, doc_id, chunk_index, content, metadata, created_at)
                VALUES (?, ?, ?, ?, CAST(? AS jsonb), now())
                """, chunkId, docId, index, content, metadata);
    }

    private void insertContent(UUID contentId, String status) {
        jdbcTemplate.update("""
                INSERT INTO contents
                    (id, title, slug, type, status, body_markdown, created_at, updated_at)
                VALUES (?, 'Content', ?, 'ARTICLE', ?, 'Body', now() - interval '1 minute', now())
                """, contentId, "content-" + contentId, status);
    }

    private String unitVector() {
        StringBuilder vector = new StringBuilder("[1");
        for (int index = 1; index < 768; index++) {
            vector.append(",0");
        }
        return vector.append(']').toString();
    }
}
